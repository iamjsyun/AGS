#ifndef CXPOSITIONMANAGER_MQH
#define CXPOSITIONMANAGER_MQH

#include "..\..\Platform\Core\Interfaces\IXPositionManager.mqh"
#include "..\..\Platform\Core\Interfaces\ICXTradingSession.mqh"
#include "..\..\Platform\Core\Interfaces\ICXContext.mqh"
#include "..\..\Platform\Core\Interfaces\ICXParam.mqh"
#include "..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Platform\Core\Defines\CXDefine.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\Platform\Core\Interfaces\IXTerminalPlatform.mqh"

/**
 * @class CXPositionManager
 * @brief 샌드박스 세션 내의 포지션 감시 및 사후 관리 담당 (v13.5 UAF & Resilience Standard)
 */
class CXPositionManager : public IXPositionManager {
private:
    ulong               m_ticket;
    ICXContext*         m_ctx;
    IXTerminalPlatform* m_terminal;

public:
    CXPositionManager(ICXContext* ctx) : m_ctx(ctx), m_ticket(0) {
        m_terminal = CX_GET_OBJ(m_ctx, "terminal_platform", IXTerminalPlatform);
    }
    virtual ~CXPositionManager() override {}

    virtual void SetMagic(ulong magic) override { m_terminal.SetMagic(magic); }

    /**
     * @brief [v13.4 Audit] 포지션 감사 문자열 생성
     */
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return "[" + actionLabel + "] INVALID_SIGNAL";

        ulong ticket = sig.GetTicket();
        double profit = 0;
        double currentSL = 0;
        
        if(m_terminal.IsPositionExists(ticket)) {
            profit = m_terminal.GetPositionProfit(ticket);
            currentSL = m_terminal.GetPositionSL(ticket);
        }

        string spec = StringFormat("Profit:%.2f, SL:%.5f", profit, currentSL);
        return CXAuditFormatter::Build(actionLabel, xp, spec);
    }

    /**
     * @brief 포지션 유효성 확인 및 상태 업데이트
     */
    virtual void Pulse(ICXParam* xp) override {
        if(IS_INVALID(m_ctx) || IS_INVALID(xp)) return;
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return;

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket == 0) return;

        //--- [v11.3 SSOC Resolution]
        ICXAssetManager* invMgr = CX_GET_OBJ(m_ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(invMgr)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("POS-MANAGER", xp, "CRITICAL: AssetManager Missing."));
            return;
        }

        // 1. 터미널에 포지션이 살아있는지 확인 (SSOC) 및 SID 검증
        if(m_terminal.IsPositionExists(ticket)) {
            string posComment = m_terminal.GetPositionComment(ticket);
            if(posComment == sig.GetSid()) {
                return; // 정상: 티켓과 SID 모두 일치
            } else {
                string mismatchMsg = StringFormat("SID Mismatch for Ticket:%I64u. (Found:%s, Expected:%s)", 
                                             ticket, posComment, sig.GetSid());
                XP_LOG_WARN(xp, CXAuditFormatter::Build("POS-MANAGER", xp, mismatchMsg));
                // SID가 다르면 내 자산이 아니므로 아래의 부재/히스토리 로직으로 진행
            }
        }

        // 1.1 [v11.6] 포지션은 없으나 '대기 오더'로 살아있는지 확인
        if(m_terminal.IsOrderExists(ticket)) {
            if(m_terminal.GetOrderComment(ticket) == sig.GetSid()) {
                XP_LOG_TRACE(xp, CXAuditFormatter::Build("POS-MANAGER", xp, StringFormat("OK: Position missing but Order:%I64u still active.", ticket)));
                return; 
            }
        }

        // 2. 포지션/오더 모두 사라졌다면(Broker Close), 히스토리를 뒤져 청산 사유 파악 (SSOC)
        string reason = "";
        int status = invMgr.CheckHistoryClosure(ticket, reason);

        if(status != XE_UNKNOWN) {
            // [v1.2 Manual Sync Mandate] 터미널 수동 종료 감지 시, 앱에 청산 정보를 제공하기 위해 xa_exit=1 설정
            sig.SetXAExit(1); 
            CXMessageProvider::UpdateStatus(sig, status, reason);
            
            IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
            if(IS_VALID(repo)) repo.UpdateStatus(sig);

            XP_LOG_INFO(xp, CXAuditFormatter::Build("POS-MANAGER", xp, "Asset closed by broker: " + reason + " (Manual Sync: xa_exit=1)"));
            return;
        }
        
        // 3. 딜(Deal) 히스토리에서도 찾지 못한 경우 (동기화 지연 대비 Retry)
        string retryKey = StringFormat("HistRetry_%I64u", ticket);
        int retryCount = 0;
        ICXParam* pOld = m_ctx.GetParam(retryKey);
        if(IS_VALID(pOld)) retryCount = pOld.GetInt();

        if(retryCount < 5) {
            CXParam* pRetry = new CXParam();
            pRetry.SetInt(retryCount + 1);
            m_ctx.Set(retryKey, pRetry);
            
            XP_LOG_DEBUG(xp, CXAuditFormatter::Build("POS-MANAGER-RETRY", xp, StringFormat("Retry:%d/5", retryCount + 1)));
            return; // 다음 틱에서 재시도
        }

        // 5회 이상 실패 시 보수적으로 청산 처리
        CXMessageProvider::UpdateStatus(sig, XE_CLOSED_SIGNAL, "Position Missing & History Timeout");
        XP_LOG_WARN(xp, CXAuditFormatter::Build("POS-MANAGER-TIMEOUT", xp));
    }

    /**
     * @brief 브로커 포지션 수정 (SL/TP) 및 상태 재확인
     */
    virtual bool ModifyPosition(ICXParam* xp, ulong ticket, double sl, double tp) override {
        XP_LOG_INFO(xp, GetAuditString(xp, "POS-MODIFY-START"));

        ICXAssetManager* invMgr = CX_GET_OBJ(m_ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(invMgr)) return false;

        // 1. 수정 시도
        if(!m_terminal.PositionModify(xp, ticket, sl, tp)) {
            string retMsg = m_terminal.GetLastRetCodeDescription();
            uint retCode = m_terminal.GetLastRetCode();
            int sysErr = GetLastError();
            string spec = StringFormat("Broker Code:%u(%s), SysErr:%d", retCode, retMsg, sysErr);
            string err_msg = CXAuditFormatter::Build("POS-MODIFY-FAIL", xp, spec);
            
            XP_LOG_ERROR(xp, err_msg);
            if(IS_VALID(xp)) xp.SetString(err_msg);
            ResetLastError();
            return false;
        }
        
        // 2. 재확인 (SSOC)
        if(invMgr.IsPositionExists(ticket)) {
            double currentSL = invMgr.GetCurrentSL(ticket);
            double currentTP = invMgr.GetCurrentTP(ticket);
            
            if(MathAbs(currentSL - sl) < _Point * 10 && MathAbs(currentTP - tp) < _Point * 10) {
                XP_LOG_OK(xp, GetAuditString(xp, "POS-MODIFY-SUCCESS"));
                return true;
            }
        }
        
        string vErr = CXAuditFormatter::Build("POS-MODIFY-VERIFY-FAIL", xp, StringFormat("ticket:%I64u", ticket));
        XP_LOG_ERROR(xp, vErr);
        if(IS_VALID(xp)) xp.SetString(vErr);
        return false;
    }

    virtual void ScanAndBind(ICXParam* xp, CObject* sessionMgr) override {
        ICXAssetManager* mgr = CX_CAST(ICXAssetManager, sessionMgr);
        if(IS_INVALID(mgr)) return;

        int total = m_terminal.GetPositionsTotal();
        for(int i = 0; i < total; i++) {
            // [v18.25] Scan by indexing terminal positions
            if(!PositionGetTicket(i)) continue;
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            if(ticket <= 0) continue;

            long magic = PositionGetInteger(POSITION_MAGIC);
            ICXConfig* cfg = CX_GET_OBJ(m_ctx, "config", ICXConfig);
            if(IS_VALID(cfg) && !cfg.IsTargetMagic(magic)) continue;

            string sid = PositionGetString(POSITION_COMMENT);
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

                // Bind ticket and transition directly to XE_EXECUTED
                sig.SetTicket(ticket);
                sig.SetStatus(XE_EXECUTED);
                sig.SetStatusMsg(StringFormat("Position Scanned and Bound. Ticket:%I64u", ticket));
                repo.UpdateStatus(sig);

                // [v18.26 Fix] Reuse persistent xp instead of stack sp to avoid invalid pointer access
                xp.SetSignal(sig);
                if(IS_VALID(mgr)) {
                    ICXTradingSession* session = mgr.CreateSession(xp);
                    if(IS_VALID(session)) {
                        session.Start(xp);
                        XP_LOG_OK(xp, StringFormat("[POS-MANAGER-SCAN] Bound new active position to session. Ticket:%I64u, SID:%s", ticket, sid));
                    } else {
                        SAFE_DELETE(sig);
                    }
                } else {
                    SAFE_DELETE(sig);
                }
                xp.SetSignal(NULL);
            } else {
                // If session exists, ensure the signal ticket is up to date (mapping pending order ticket to active position ticket)
                ICXSignal* sig = existing.GetSignal();
                if(IS_VALID(sig) && sig.GetTicket() != ticket) {
                    if(sig.GetStatus() < XE_EXECUTED) {
                        sig.SetTag("LIMIT_FILL"); // [v1.0] 진입 경로 태깅 (지정가 체결)
                        sig.SetStatus(XE_EXECUTED);
                        sig.SetStatusMsg(StringFormat("Limit Fill Detected. Ticket:%I64u", ticket));
                        
                        IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
                        if(IS_VALID(repo)) repo.UpdateStatus(sig);
                        XP_LOG_OK(xp, StringFormat("[POS-MANAGER-SCAN] Limit Order Filled. Tag:LIMIT_FILL, Ticket:%I64u, SID:%s", ticket, sid));
                    }
                    sig.SetTicket(ticket);
                }
            }
        }
        
        // [v11.4 Mandate] Dangling Pointer Protection
        if(IS_VALID(xp)) xp.SetSignal(NULL);
    }
};

#endif
