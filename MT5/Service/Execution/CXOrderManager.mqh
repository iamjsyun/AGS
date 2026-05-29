#ifndef CXORDERMANAGER_MQH
#define CXORDERMANAGER_MQH

#include "..\..\Core\Interfaces\IXOrderManager.mqh"
#include "..\..\Core\Interfaces\ICXTradingSession.mqh"
#include "..\..\Core\Interfaces\ICXContext.mqh"
#include "..\..\Core\Interfaces\ICXParam.mqh"
#include "..\..\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\Core\Interfaces\ICXRiskManager.mqh"
#include "..\..\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Core\Interfaces\ICXAuditProvider.mqh"
#include "..\..\Core\Interfaces\IXGuard.mqh"
#include "..\..\Core\Defines\CXDefine.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Logger\CXMessageProvider.mqh"
#include "..\..\Core\Interfaces\IXTerminalPlatform.mqh"

/**
 * @class CXOrderManager
 * @brief 주문 전송 및 관리 전담 구현체 (v13.5 UAF & Resilience Standard)
 */
class CXOrderManager : public IXOrderManager {
private:
    ulong               m_ticket;
    string              m_sid;
    IXTerminalPlatform* m_terminal;
    ICXContext*         m_ctx;

public:
    CXOrderManager(ICXContext* ctx) : m_ctx(ctx), m_ticket(0), m_sid("") {
        m_terminal = CX_GET_OBJ(m_ctx, "terminal_platform", IXTerminalPlatform);
    }
    virtual ~CXOrderManager() override {}

    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") override {
        ICXSignal* sig = xp.GetSignal();
        if(!CXLogDispatcher::IsOk(sig)) return "[FUNC:" + actionLabel + "] INVALID_SIGNAL";
        
        string spec = xp.GetString();
        if(spec == "") {
            string symbol = sig.GetSymbol();
            ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
            ICXPriceManager* priceMgr = CX_GET_OBJ(m_ctx, "price_mgr", ICXPriceManager);
            double point = CXLogDispatcher::IsOk(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
            double mkt   = CXLogDispatcher::IsOk(priceMgr) ? priceMgr.GetMarketPrice(symbol, sig.GetDir()) : SymbolInfoDouble(symbol, (sig.GetDir() == CX_DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);
            
            // [v1.1 Fix] 실시간 시장가(mkt) 대신 '고정 참조 가격' 기반으로 논리적 트리거 가격 산출 (Jitter 제거)
            double refPrice = sig.GetPriceSignal();
            if(refPrice <= 0) refPrice = sig.GetPriceOpen();

            string activeKey = "TE_Active_" + sig.GetSid();
            ICXParam* pActive = m_ctx.GetParam(activeKey);
            bool isActive = (CXLogDispatcher::IsOk(pActive) && pActive.GetInt() == 1);

            double tesp = 0;
            double telp = 0;

            if(!isActive) {
                // 1. 활성화 전: 신호 가격 대비 TEStart 포인트 (고정된 진입 장벽 표시)
                tesp = refPrice + (sig.GetTEStart() * point * (sig.GetDir()==CX_DIR_BUY?-1:1));
                telp = refPrice + (sig.GetTELimit() * point * (sig.GetDir()==CX_DIR_BUY?-1:1));
            } else {
                // 2. 활성화 후: 극점(Extremity) 대비 TEStep 포인트 (움직이는 반등 트리거선 표시)
                string extKey = "LastEntryExtremity_" + sig.GetSid();
                ICXParam* pExt = m_ctx.GetParam(extKey);
                if(CXLogDispatcher::IsOk(pExt) && pExt.GetDouble() > 0) refPrice = pExt.GetDouble();
                
                tesp = refPrice - (sig.GetTEStep() * point * (sig.GetDir()==CX_DIR_BUY?-1:1));
                telp = refPrice + (sig.GetTELimit() * point * (sig.GetDir()==CX_DIR_BUY?-1:1));
            }
            
            spec = StringFormat("ESTART:%d, ESTART_PRICE:%.2f, ELIMIT_PRICE:%.2f", (int)sig.GetTEStart(), tesp, telp);
        }

        return CXAuditFormatter::Build(actionLabel, xp, spec);
    }

    virtual void SetMagic(ulong magic) override { m_terminal.SetMagic(magic); }

    virtual void Pulse(ICXParam* xp) override {
        if(IS_INVALID(m_ctx) || IS_INVALID(xp)) return;
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return;

        ulong ticket = sig.GetTicket();
        if(ticket == 0) return;

        ICXAssetManager* invMgr = CX_GET_OBJ(m_ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(invMgr)) return;

        // 1. 오더가 아직 존재하면 정상 (대기 중)
        if(invMgr.IsOrderExists(ticket)) return;
        
        // 2. 오더가 없는데 포지션이 있으면 정상 (체결됨)
        if(invMgr.IsPositionExists(ticket)) return;

        string reason = "";
        int status = invMgr.CheckHistoryClosure(ticket, reason);
        // ... (History retry logic follows as in original)

        if(status != XE_UNKNOWN) {
            // [v1.2 Manual Sync Mandate] 터미널 수동 취소 감지 시, 앱에 정보를 제공하기 위해 xa_exit=1 설정
            sig.SetXAExit(1);
            IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
            CXMessageProvider::UpdateStatus(sig, status, reason);
            if(IS_VALID(repo)) repo.UpdateStatus(sig);
            XP_LOG_INFO(xp, CXAuditFormatter::Build("ORDER-MANAGER", xp, "Asset Closure Detected: " + reason + " (Manual Sync: xa_exit=1)"));
            return;
        }

        string retryKey = StringFormat("OrdHistRetry_%I64u", ticket);
        int retryCount = 0;
        ICXParam* pOld = m_ctx.GetParam(retryKey);
        if(IS_VALID(pOld)) retryCount = pOld.GetInt();

        if(retryCount < 5) {
            CXParam* pRetry = new CXParam();
            pRetry.SetInt(retryCount + 1);
            m_ctx.Set(retryKey, pRetry);
            return;
        }

        IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
        CXMessageProvider::UpdateStatus(sig, XE_CLOSED_SIGNAL, "Order History Timeout");
        if(IS_VALID(repo)) repo.UpdateStatus(sig);
    }

    virtual bool ExecuteEntry(ICXParam* xp) override {
        if(IS_NULL(m_ctx) || IS_NULL(xp)) return false;
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return false;

        string sid = sig.GetSid(); StringTrimLeft(sid); StringTrimRight(sid);
        ulong magic = sig.GetMagic();

        // [v18.8 Safety Guard] 
        // Minimum check: If ticket already exists in the object, never send another order.
        if(sig.GetTicket() > 0 || sig.GetStatus() >= XE_IN_TRANSIT) {
             XP_LOG_WARN(xp, CXAuditFormatter::Build("EXEC-ENTRY-GUARD", xp, "ABORT: Signal already has a ticket or is in transit."));
             return true; 
        }

        // [v14.40 Throttled Retry]
        // If we recently failed with Market Closed, wait at least 60 seconds before trying again.
        string retryTimerKey = "EntryRetryTimer_" + sid;
        ICXParam* pTimer = m_ctx.GetParam(retryTimerKey);
        if(IS_VALID(pTimer)) {
            if(TimeCurrent() < (datetime)pTimer.GetLong()) {
                xp.SetString("WAIT_MARKET_OPEN"); // Stay in wait state
                return false;
            }
        }

        string symbol = sig.GetSymbol();
        int    dir    = sig.GetDir();
        double lot    = sig.GetLot();
        string comment = sid;
        m_sid = comment;

        double execPrice = sig.GetPriceOpen();
        double finalSL   = sig.GetPriceSL();
        double finalTP   = sig.GetPriceTP();
        
        ENUM_ORDER_TYPE order_type = (sig.GetType() == ORDER_MARKET) ? 
                                     (dir == CX_DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL) : 
                                     (dir == CX_DIR_BUY ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);

        m_terminal.SetMagic(magic);
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        ICXPriceManager* priceMgr = CX_GET_OBJ(m_ctx, "price_mgr", ICXPriceManager);
        
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        double currentMkt = IS_VALID(priceMgr) ? priceMgr.GetMarketPrice(symbol, dir) : SymbolInfoDouble(symbol, (dir == CX_DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);
        int stopsLevel = IS_VALID(symMgr) ? symMgr.GetStopsLevel(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minDistance = (stopsLevel + 1) * point;
        
        if(sig.GetType() != ORDER_MARKET) {
            // [v16.12 Fix] Exact Limit Order Price Clamping based on StopsLevel
            // For BUY LIMIT, the limit price must be <= (Current Ask - StopsLevel)
            // For SELL LIMIT, the limit price must be >= (Current Bid + StopsLevel)
            if(dir == CX_DIR_BUY && execPrice > currentMkt - minDistance) {
                execPrice = currentMkt - minDistance;
                XP_LOG_WARN(xp, CXAuditFormatter::Build("EXEC-ENTRY-ADJ", xp, StringFormat("Buy Limit price adjusted down to %.5f due to StopsLevel", execPrice)));
            }
            else if (dir == CX_DIR_SELL && execPrice < currentMkt + minDistance) {
                execPrice = currentMkt + minDistance;
                XP_LOG_WARN(xp, CXAuditFormatter::Build("EXEC-ENTRY-ADJ", xp, StringFormat("Sell Limit price adjusted up to %.5f due to StopsLevel", execPrice)));
            }
        }

        string funcName = (sig.GetType() == ORDER_MARKET) ? "PositionOpen" : "OrderOpen";
        
        // [v11.10] Pre-Call Raw Parameter Audit
        string rawParams = StringFormat("Raw: [Sym:%s, Lot:%.2f, Type:%d, P:%.2f, SL:%.2f, TP:%.2f, Magic:%I64d, SID:%s]",
                                        symbol, lot, order_type, execPrice, finalSL, finalTP, magic, comment);
        xp.SetString(rawParams);
        string auditMsg = GetAuditString(xp, "AUDIT-CALL:" + funcName);
        XP_LOG_OK(xp, auditMsg);
        Print(auditMsg);

        IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
        if(sig.GetType() == ORDER_MARKET) {
            sig.SetTag("ENTRY_MARKET");
        }
        CXMessageProvider::UpdateStatus(sig, sig.GetStatus(), "Calling " + funcName + "...");
        if(IS_VALID(repo)) repo.UpdateStatus(sig);

        bool success = (sig.GetType() == ORDER_MARKET) ?
            m_terminal.PositionOpen(xp, sig, execPrice, finalSL, finalTP) :
            m_terminal.OrderOpen(xp, sig, execPrice, finalSL, finalTP);

        xp.SetString(""); // Clear for next use
        uint retCode = m_terminal.GetLastRetCode();
        string receptionMsg = CXAuditFormatter::Build("AUDIT-RECEPTION", xp, StringFormat("%s Result: %s (Code:%u)", funcName, success?"SUCCESS":"FAILED", retCode));
        XP_LOG_INFO(xp, receptionMsg);
        Print(receptionMsg);

        if(!success) {
            string errDescription = m_terminal.GetLastRetCodeDescription();
            string err = StringFormat("%s FAIL. Code:%u(%s)", funcName, retCode, errDescription);

            // [v14.32 Resilience] Market Closed (10018) is a transient state, not a fatal error.
            if(retCode == 10018) {
                XP_LOG_WARN(xp, CXAuditFormatter::Build("EXEC-ENTRY-WAIT", xp, "Market Closed. Throttling retry for 60s."));
                CXMessageProvider::UpdateStatus(sig, sig.GetStatus(), "Waiting: Market Closed");
                if(IS_VALID(repo)) repo.UpdateStatus(sig);
                
                // Set throttle timer
                CXParam* pNewTimer = new CXParam();
                pNewTimer.SetLong((long)(TimeCurrent() + 60));
                m_ctx.Set(retryTimerKey, pNewTimer);

                xp.SetString("WAIT_MARKET_OPEN"); // Pass signal to task
                return false;
            }

            XP_LOG_ERROR(xp, CXAuditFormatter::Build("EXEC-ENTRY-FAIL", xp, err));
            CXMessageProvider::UpdateStatus(sig, XE_ERROR, err);
            if(IS_VALID(repo)) repo.UpdateStatus(sig);
            return false;
        }

        ulong ticket = m_terminal.GetLastResultOrder();
        if(ticket == 0) ticket = m_terminal.GetLastResultDeal();
        sig.SetTicket(ticket);
        CXMessageProvider::UpdateStatus(sig, XE_IN_TRANSIT, "Order Placed: " + (string)ticket);
        if(IS_VALID(repo)) repo.UpdateStatus(sig);

        return true;
    }

    virtual bool ExecuteExit(ICXParam* xp) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return false;
        ulong ticket = (ulong)sig.GetTicket();
        if(ticket <= 0) return false;

        string funcName = m_terminal.IsPositionExists(ticket) ? "PositionClose" : "OrderDelete";
        
        // [v11.10] Pre-Call Raw Parameter Audit
        string rawParams = StringFormat("Raw: [Ticket:%I64u, SID:%s]", ticket, sig.GetSid());
        xp.SetString(rawParams);
        string auditMsg = GetAuditString(xp, "AUDIT-CALL:" + funcName);
        XP_LOG_INFO(xp, auditMsg);
        Print(auditMsg);
        
        bool success = m_terminal.IsPositionExists(ticket) ? m_terminal.PositionClose(xp, ticket) : m_terminal.OrderDelete(xp, ticket);
        
        xp.SetString(""); // Clear for next use
        PrintFormat("[AUDIT-RECEPTION] %s Result: %s (Code:%u)", funcName, success?"SUCCESS":"FAILED", m_terminal.GetLastRetCode());
        return success;
    }

    virtual bool ModifyOrder(ICXParam* xp, ulong ticket, double price, double sl, double tp) override {
        // [v11.10] Pre-Call Raw Parameter Audit
        string rawParams = StringFormat("Raw: [Ticket:%I64u, P:%.2f, SL:%.2f, TP:%.2f]", ticket, price, sl, tp);
        xp.SetString(rawParams);
        string auditMsg = GetAuditString(xp, "AUDIT-CALL:OrderModify");
        XP_LOG_INFO(xp, auditMsg);
        Print(auditMsg);
        
        bool success = m_terminal.OrderModify(xp, ticket, price, sl, tp);
        
        xp.SetString(""); // Clear for next use
        uint retCode = m_terminal.GetLastRetCode();
        string receptionMsg = CXAuditFormatter::Build("AUDIT-RECEPTION", xp, StringFormat("OrderModify Result: %s (Code:%u)", success?"SUCCESS":"FAILED", retCode));
        XP_LOG_INFO(xp, receptionMsg);
        Print(receptionMsg);
        
        if(!success && retCode == 10018) {
             XP_LOG_WARN(xp, CXAuditFormatter::Build("EXEC-MOD-WAIT", xp, "Market Closed during modification."));
             xp.SetString("WAIT_MARKET_OPEN");
        }
        
        return success;
    }

    virtual bool ModifyPosition(ICXParam* xp, ulong ticket, double sl, double tp) override {
        // [v11.10] Pre-Call Raw Parameter Audit
        string rawParams = StringFormat("Raw: [Ticket:%I64u, SL:%.2f, TP:%.2f]", ticket, sl, tp);
        xp.SetString(rawParams);
        string auditMsg = GetAuditString(xp, "AUDIT-CALL:PositionModify");
        XP_LOG_INFO(xp, auditMsg);
        Print(auditMsg);
        
        bool success = m_terminal.PositionModify(xp, ticket, sl, tp);
        
        xp.SetString(""); // Clear for next use
        uint retCode = m_terminal.GetLastRetCode();
        string receptionMsg = CXAuditFormatter::Build("AUDIT-RECEPTION", xp, StringFormat("PositionModify Result: %s (Code:%u)", success?"SUCCESS":"FAILED", retCode));
        XP_LOG_INFO(xp, receptionMsg);
        Print(receptionMsg);

        if(!success && retCode == 10018) {
             XP_LOG_WARN(xp, CXAuditFormatter::Build("EXEC-POS-WAIT", xp, "Market Closed during position modification."));
             xp.SetString("WAIT_MARKET_OPEN");
        }
        
        return success;
    }

    virtual bool DeleteOrder(ICXParam* xp, ulong ticket) override {
        // [v11.10] Pre-Call Raw Parameter Audit
        string rawParams = StringFormat("Raw: [Ticket:%I64u]", ticket);
        xp.SetString(rawParams);
        string auditMsg = GetAuditString(xp, "AUDIT-CALL:OrderDelete");
        XP_LOG_INFO(xp, auditMsg);
        Print(auditMsg);
        
        bool success = m_terminal.OrderDelete(xp, ticket);
        
        xp.SetString(""); // Clear for next use
        uint retCode = m_terminal.GetLastRetCode();
        string receptionMsg = CXAuditFormatter::Build("AUDIT-RECEPTION", xp, StringFormat("OrderDelete Result: %s (Code:%u)", success?"SUCCESS":"FAILED", retCode));
        XP_LOG_INFO(xp, receptionMsg);
        Print(receptionMsg);
        
        return success;
    }

    virtual void ScanAndBind(ICXParam* xp, CObject* sessionMgr) override {
        ICXAssetManager* mgr = CX_CAST(ICXAssetManager, sessionMgr);
        if(IS_INVALID(mgr)) return;

        int total = m_terminal.GetOrdersTotal();
        for(int i = 0; i < total; i++) {
            // [v18.25] Scan by indexing terminal orders
            if(!OrderGetTicket(i)) continue;
            ulong ticket = OrderGetInteger(ORDER_TICKET);
            if(ticket <= 0) continue;
            
            long magic = OrderGetInteger(ORDER_MAGIC);
            ICXConfig* cfg = CX_GET_OBJ(m_ctx, "config", ICXConfig);
            if(IS_VALID(cfg) && !cfg.IsTargetMagic(magic)) continue;

            string sid = OrderGetString(ORDER_COMMENT);
            StringTrimLeft(sid); StringTrimRight(sid);
            if(sid == "") continue;

            // Check if active session already exists for this SID
            ICXTradingSession* existing = mgr.FindSessionBySid(sid);
            if(IS_INVALID(existing)) {
                IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
                if(IS_INVALID(repo)) continue;

                ICXSignal* sig = repo.GetSignalBySid(sid);
                if(IS_INVALID(sig)) continue; // Orphan or Zombie asset, handled by ReverseInjector

                if(sig.GetStatus() >= XE_CLOSED_SIGNAL) {
                    SAFE_DELETE(sig);
                    continue;
                }

                // Bind ticket and transition to XE_PENDING_PLACED
                sig.SetTicket(ticket);
                sig.SetStatus(XE_PENDING_PLACED);
                sig.SetStatusMsg(StringFormat("Order Scanned and Bound. Ticket:%I64u", ticket));
                repo.UpdateStatus(sig);

                // [v18.26 Fix] Reuse persistent xp instead of stack sp
                xp.SetSignal(sig);
                if(IS_VALID(mgr)) {
                    ICXTradingSession* session = mgr.CreateSession(xp);
                    if(IS_VALID(session)) {
                        session.Start(xp);
                        // Only log the initial binding success per ticket
                        XP_LOG_OK(xp, StringFormat("[ORDER-MANAGER-SCAN] Successfully bound new pending order. Ticket:%I64u, SID:%s", ticket, sid));
                    } else {
                        SAFE_DELETE(sig);
                    }
                } else {
                    SAFE_DELETE(sig);
                }
                xp.SetSignal(NULL);
            } else {
                // If session exists, ensure the signal ticket is up to date without logging every scan
                ICXSignal* sig = existing.GetSignal();
                if(IS_VALID(sig) && sig.GetTicket() != ticket) {
                    sig.SetTicket(ticket);
                }
            }
        }

        // [v11.4 Mandate] Dangling Pointer Protection
        if(IS_VALID(xp)) xp.SetSignal(NULL);
    }
};

#endif
