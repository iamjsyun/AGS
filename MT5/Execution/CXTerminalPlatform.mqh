#ifndef CXTERMINALPLATFORM_MQH
#define CXTERMINALPLATFORM_MQH

#include "..\Platform\Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\Platform\Core\Interfaces\ICXContext.mqh"
#include "..\Platform\Core\Defines\CXDefine.mqh"
#include "..\Platform\Core\Macros\CXMacros.mqh"
#include "..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include <Trade\Trade.mqh>

/**
 * @class CXTerminalPlatform
 * @brief MT5 터미널 및 브로커 연동 구상 플랫폼 클래스 (v11.1 Logging & MT5 API Encapsulation)
 */
class CXTerminalPlatform : public IXTerminalPlatform {
private:
    ICXContext* m_ctx;
    CTrade      m_trade;

public:
    CXTerminalPlatform(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXTerminalPlatform() override {}

    virtual void SetMagic(ulong magic) override {
        m_trade.SetExpertMagicNumber(magic);
    }

    //--- 1. 거래 실행 (Trade Operations)
    
    virtual bool PositionOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override {
        if(IS_INVALID(sig)) return false;
        string symbol = sig.GetSymbol();
        double lot = sig.GetLot();
        int dir = sig.GetDir();
        ulong magic = sig.GetMagic();
        string sid = sig.GetSid();
        ENUM_ORDER_TYPE order_type = (dir == CX_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

        // [v11.10 Pre-Call Audit] Log all raw parameters before broker call
        XP_LOG_INFO(xp, StringFormat("[BROKER-CALL] PositionOpen(Sym:%s, Type:%d, Lot:%.2f, Price:%.5f, SL:%.5f, TP:%.5f, Magic:%I64u, SID:%s)",
                                      symbol, order_type, lot, price, sl, tp, magic, sid));

        m_trade.SetExpertMagicNumber(magic);
        
        double currentMkt = SymbolInfoDouble(symbol, (dir == CX_DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);
        
        bool res = m_trade.PositionOpen(symbol, order_type, lot, price, sl, tp, sid);
        uint retCode = m_trade.ResultRetcode();
        string desc = m_trade.ResultRetcodeDescription();
        int err = GetLastError();

        if(res) {
            XP_LOG_OK(xp, StringFormat("[EXEC-ENTRY] Sending Order: [Sym:%s, Type:%s, Lot:%.2f, Price:%.5f, SL:%.5f, TP:%.5f, Mkt:%.5f, M:%I64u, SID:%s]",
                                       symbol, (dir == CX_DIR_BUY) ? "BUY" : "SELL", lot, price, sl, tp, currentMkt, magic, sid));
        } else {
            XP_LOG_ERROR(xp, StringFormat("[EXEC-ENTRY-FAIL] Broker Code:%u(%s), SysErr:%d. Raw: [Sym:%s, Lot:%.2f, P:%.5f, SL:%.5f, TP:%.5f, M:%I64u, SID:%s]",
                                          retCode, desc, err, symbol, lot, price, sl, tp, magic, sid));
            ResetLastError();
        }

        return res;
    }

    virtual bool OrderOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override {
        if(IS_INVALID(sig)) return false;
        string symbol = sig.GetSymbol();
        double lot = sig.GetLot();
        int dir = sig.GetDir();
        ulong magic = sig.GetMagic();
        string sid = sig.GetSid();
        ENUM_ORDER_TYPE order_type = (dir == CX_DIR_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;

        // [v11.10 Pre-Call Audit] Log all raw parameters before broker call
        XP_LOG_INFO(xp, StringFormat("[BROKER-CALL] OrderOpen(Sym:%s, Type:%d, Lot:%.2f, Price:%.5f, SL:%.5f, TP:%.5f, Magic:%I64u, SID:%s)",
                                      symbol, order_type, lot, price, sl, tp, magic, sid));

        m_trade.SetExpertMagicNumber(magic);
        
        double currentMkt = SymbolInfoDouble(symbol, (dir == CX_DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);

        bool res = m_trade.OrderOpen(symbol, order_type, lot, 0, price, sl, tp, ORDER_TIME_GTC, 0, sid);
        uint retCode = m_trade.ResultRetcode();
        string desc = m_trade.ResultRetcodeDescription();
        int err = GetLastError();

        if(res) {
            XP_LOG_OK(xp, StringFormat("[EXEC-ENTRY] Sending Order: [Sym:%s, Type:%s, Lot:%.2f, Price:%.5f, SL:%.5f, TP:%.5f, Mkt:%.5f, M:%I64u, SID:%s]",
                                       symbol, (dir == CX_DIR_BUY) ? "BUY_LIMIT" : "SELL_LIMIT", lot, price, sl, tp, currentMkt, magic, sid));
        } else {
            XP_LOG_ERROR(xp, StringFormat("[EXEC-ENTRY-FAIL] Broker Code:%u(%s), SysErr:%d. Raw: [Sym:%s, Lot:%.2f, P:%.5f, SL:%.5f, TP:%.5f, M:%I64u, SID:%s]",
                                          retCode, desc, err, symbol, lot, price, sl, tp, magic, sid));
            ResetLastError();
        }

        return res;
    }

    virtual bool PositionModify(ICXParam* xp, ulong ticket, double sl, double tp) override {
        long magic = 0;
        if(PositionSelectByTicket(ticket)) magic = PositionGetInteger(POSITION_MAGIC);

        // [v11.10 Pre-Call Audit] 
        XP_LOG_INFO(xp, StringFormat("[BROKER-CALL] PositionModify(Ticket:%I64u, SL:%.5f, TP:%.5f, Magic:%I64d)",
                                      ticket, sl, tp, magic));

        m_trade.SetExpertMagicNumber(magic);

        bool res = m_trade.PositionModify(ticket, sl, tp);
        uint retCode = m_trade.ResultRetcode();
        string desc = m_trade.ResultRetcodeDescription();
        int err = GetLastError();

        if(res) {
            XP_LOG_OK(xp, StringFormat("[POS-MODIFY] Sending Request: [Ticket:%I64u, M:%I64d, SL:%.5f, TP:%.5f]",
                                       ticket, magic, sl, tp));
        } else {
            XP_LOG_ERROR(xp, StringFormat("[POS-MODIFY-FAIL] Broker Code:%u(%s), SysErr:%d. Raw: [Ticket:%I64u, M:%I64d, SL:%.5f, TP:%.5f]",
                                          retCode, desc, err, ticket, magic, sl, tp));
            ResetLastError();
        }

        return res;
    }

    virtual bool OrderModify(ICXParam* xp, ulong ticket, double price, double sl, double tp) override {
        long magic = 0;
        if(OrderSelect(ticket)) magic = OrderGetInteger(ORDER_MAGIC);

        // [v11.10 Pre-Call Audit] 
        XP_LOG_INFO(xp, StringFormat("[BROKER-CALL] OrderModify(Ticket:%I64u, Price:%.5f, SL:%.5f, TP:%.5f, Magic:%I64d)",
                                      ticket, price, sl, tp, magic));

        m_trade.SetExpertMagicNumber(magic);

        bool res = m_trade.OrderModify(ticket, price, sl, tp, ORDER_TIME_GTC, 0);
        uint retCode = m_trade.ResultRetcode();
        string desc = m_trade.ResultRetcodeDescription();
        int err = GetLastError();

        if(res) {
            XP_LOG_OK(xp, StringFormat("[ORDER-MODIFY] Sending Request: [Ticket:%I64u, M:%I64d, Price:%.5f, SL:%.5f, TP:%.5f]",
                                       ticket, magic, price, sl, tp));
        } else {
            XP_LOG_ERROR(xp, StringFormat("[ORDER-MODIFY-FAIL] Broker Code:%u(%s), SysErr:%d. Raw: [Ticket:%I64u, M:%I64d, Price:%.5f, SL:%.5f, TP:%.5f]",
                                          retCode, desc, err, ticket, magic, price, sl, tp));
            ResetLastError();
        }

        return res;
    }

    virtual bool PositionClose(ICXParam* xp, ulong ticket) override {
        long magic = 0;
        if(PositionSelectByTicket(ticket)) magic = PositionGetInteger(POSITION_MAGIC);

        // [v11.10 Pre-Call Audit] 
        XP_LOG_INFO(xp, StringFormat("[BROKER-CALL] PositionClose(Ticket:%I64u, Magic:%I64d)",
                                      ticket, magic));

        m_trade.SetExpertMagicNumber(magic);

        bool res = m_trade.PositionClose(ticket);
        uint retCode = m_trade.ResultRetcode();
        string desc = m_trade.ResultRetcodeDescription();
        int err = GetLastError();

        if(res) {
            XP_LOG_OK(xp, StringFormat("[ORDER-DELETE] Sending Request: [Ticket:%I64u, M:%I64d] (PositionClose)", ticket, magic));
        } else {
            XP_LOG_ERROR(xp, StringFormat("[ORDER-DELETE-FAIL] Broker Code:%u(%s), SysErr:%d. Raw: [Ticket:%I64u, M:%I64d] (PositionClose)",
                                          retCode, desc, err, ticket, magic));
            ResetLastError();
        }

        return res;
    }

    virtual bool OrderDelete(ICXParam* xp, ulong ticket) override {
        long magic = 0;
        if(OrderSelect(ticket)) magic = OrderGetInteger(ORDER_MAGIC);

        // [v11.10 Pre-Call Audit] 
        XP_LOG_INFO(xp, StringFormat("[BROKER-CALL] OrderDelete(Ticket:%I64u, Magic:%I64d)",
                                      ticket, magic));

        m_trade.SetExpertMagicNumber(magic);

        bool res = m_trade.OrderDelete(ticket);
        uint retCode = m_trade.ResultRetcode();
        string desc = m_trade.ResultRetcodeDescription();
        int err = GetLastError();

        if(res) {
            XP_LOG_OK(xp, StringFormat("[ORDER-DELETE] Sending Request: [Ticket:%I64u, M:%I64d]", ticket, magic));
        } else {
            XP_LOG_ERROR(xp, StringFormat("[ORDER-DELETE-FAIL] Broker Code:%u(%s), SysErr:%d. Raw: [Ticket:%I64u, M:%I64d]",
                                          retCode, desc, err, ticket, magic));
            ResetLastError();
        }

        return res;
    }

    //--- 2. 계좌 정보 조회 (Account Information)
    
    virtual double GetAccountBalance() override { return AccountInfoDouble(ACCOUNT_BALANCE); }
    virtual double GetAccountEquity() override { return AccountInfoDouble(ACCOUNT_EQUITY); }
    virtual double GetAccountMargin() override { return AccountInfoDouble(ACCOUNT_MARGIN); }
    virtual double GetAccountFreeMargin() override { return AccountInfoDouble(ACCOUNT_MARGIN_FREE); }
    virtual long   GetAccountLeverage() override { return AccountInfoInteger(ACCOUNT_LEVERAGE); }

    //--- 3. 실물 자산 상태 조회 (Asset Queries)
    
    virtual bool IsPositionExists(ulong ticket) override {
        if(ticket <= 0) return false;
        return PositionSelectByTicket(ticket);
    }

    virtual bool IsOrderExists(ulong ticket) override {
        if(ticket <= 0) return false;
        return OrderSelect(ticket);
    }

    virtual double GetPositionVolume(ulong ticket) override {
        return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_VOLUME) : 0;
    }

    virtual double GetPositionPriceOpen(ulong ticket) override {
        return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_PRICE_OPEN) : 0;
    }

    virtual double GetOrderVolume(ulong ticket) override {
        return OrderSelect(ticket) ? OrderGetDouble(ORDER_VOLUME_CURRENT) : 0;
    }

    virtual double GetOrderPriceOpen(ulong ticket) override {
        return OrderSelect(ticket) ? OrderGetDouble(ORDER_PRICE_OPEN) : 0;
    }

    virtual double GetOrderSL(ulong ticket) override {
        return OrderSelect(ticket) ? OrderGetDouble(ORDER_SL) : 0;
    }

    virtual double GetOrderTP(ulong ticket) override {
        return OrderSelect(ticket) ? OrderGetDouble(ORDER_TP) : 0;
    }

    virtual int GetPositionsTotal() override {
        return PositionsTotal();
    }

    virtual int GetOrdersTotal() override {
        return OrdersTotal();
    }

    virtual double GetPositionSL(ulong ticket) override {
        return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_SL) : 0;
    }

    virtual double GetPositionTP(ulong ticket) override {
        return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_TP) : 0;
    }

    virtual double GetPositionProfit(ulong ticket) override {
        return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_PROFIT) : 0.0;
    }

    virtual string GetPositionComment(ulong ticket) override {
        return PositionSelectByTicket(ticket) ? PositionGetString(POSITION_COMMENT) : "";
    }

    virtual string GetOrderComment(ulong ticket) override {
        return OrderSelect(ticket) ? OrderGetString(ORDER_COMMENT) : "";
    }

    virtual int CheckHistoryClosure(ulong ticket, string &outReason) override {
        if(ticket <= 0) {
            outReason = "Invalid Ticket (0)";
            return XE_UNKNOWN;
        }

        if(HistorySelect(0, TimeCurrent())) {
            int total = HistoryDealsTotal();
            for(int i = total - 1; i >= 0; i--) {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket &&
                   HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                   
                    outReason = HistoryDealGetString(dealTicket, DEAL_COMMENT);
                    
                    if(StringFind(outReason, "[sl]") >= 0 || StringFind(outReason, "sl") >= 0) {
                        outReason = "Closed by SL (" + outReason + ")";
                        return XE_CLOSED_SL;
                    } 
                    if(StringFind(outReason, "[tp]") >= 0 || StringFind(outReason, "tp") >= 0) {
                        outReason = "Closed by TP (" + outReason + ")";
                        return XE_CLOSED_TP;
                    }
                    
                    outReason = "Closed by Broker/Manual (" + outReason + ")";
                    return XE_CLOSED_SIGNAL;
                }
            }

            int totalOrders = HistoryOrdersTotal();
            for(int i = totalOrders - 1; i >= 0; i--) {
                ulong histTicket = HistoryOrderGetTicket(i);
                if(histTicket == ticket) {
                    ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(histTicket, ORDER_STATE);
                    if(state == ORDER_STATE_CANCELED) {
                        outReason = "Pending Order Canceled by User/Broker";
                        return XE_CLOSED_SIGNAL;
                    }
                    if(state == ORDER_STATE_EXPIRED) {
                        outReason = "Pending Order Expired";
                        return XE_CLOSED_SIGNAL;
                    }
                }
            }
        }
        
        outReason = "Asset Not Found in Terminal/History";
        return XE_UNKNOWN;
    }

    virtual bool VerifyPhysicalAbsence(ulong magic, string sid) override {
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong t = PositionGetTicket(i);
            if(PositionSelectByTicket(t)) {
                if(PositionGetInteger(POSITION_MAGIC) == (long)magic && PositionGetString(POSITION_COMMENT) == sid) return false;
            }
        }
        for(int i = 0; i < OrdersTotal(); i++) {
            ulong t = OrderGetTicket(i);
            if(OrderSelect(t)) {
                if(OrderGetInteger(ORDER_MAGIC) == (long)magic && OrderGetString(ORDER_COMMENT) == sid) return false;
            }
        }
        return true;
    }

    virtual ulong GetTicketBySid(ulong magic, string sid) override {
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong t = PositionGetTicket(i);
            if(PositionSelectByTicket(t)) {
                if(PositionGetInteger(POSITION_MAGIC) == (long)magic && PositionGetString(POSITION_COMMENT) == sid) return t;
            }
        }
        for(int i = 0; i < OrdersTotal(); i++) {
            ulong t = OrderGetTicket(i);
            if(OrderSelect(t)) {
                if(OrderGetInteger(ORDER_MAGIC) == (long)magic && OrderGetString(ORDER_COMMENT) == sid) return t;
            }
        }
        return 0;
    }

    virtual bool SweepBySid(ICXParam* xp, ulong magic, string sid) override {
        bool all_cleared = true;
        XP_LOG_WARN(xp, CXAuditFormatter::Build("EXIT-SWEEP-START", xp, "Starting Fallback Sweep for SID:" + sid));
        
        //-- 포지션 스윕
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong t = PositionGetTicket(i);
            if(PositionSelectByTicket(t)) {
                if(PositionGetInteger(POSITION_MAGIC) == (long)magic && PositionGetString(POSITION_COMMENT) == sid) {
                    XP_LOG_INFO(xp, CXAuditFormatter::Build("POS-CLOSE-SWEEP", xp, StringFormat("Sending Request [Ticket:%I64u]", t)));
                    if(!PositionClose(xp, t)) {
                        all_cleared = false;
                        string err_msg = StringFormat("SWEEP FAILED for Ticket:%I64u", t);
                        XP_LOG_ERROR(xp, CXAuditFormatter::Build("POS-CLOSE-FAIL", xp, err_msg));
                        if(IS_VALID(xp)) xp.SetString("[POS-CLOSE-FAIL] " + err_msg);
                    }
                }
            }
        }
        //-- 주문 스윕
        for(int i = OrdersTotal() - 1; i >= 0; i--) {
            ulong t = OrderGetTicket(i);
            if(OrderSelect(t)) {
                if(OrderGetInteger(ORDER_MAGIC) == (long)magic && OrderGetString(ORDER_COMMENT) == sid) {
                    XP_LOG_INFO(xp, CXAuditFormatter::Build("ORDER-DELETE-SWEEP", xp, StringFormat("Sending Request [Ticket:%I64u]", t)));
                    if(!OrderDelete(xp, t)) {
                        all_cleared = false;
                        string err_msg = StringFormat("SWEEP FAILED for Ticket:%I64u", t);
                        XP_LOG_ERROR(xp, CXAuditFormatter::Build("ORDER-DELETE-FAIL", xp, err_msg));
                        if(IS_VALID(xp)) xp.SetString("[ORDER-DELETE-FAIL] " + err_msg);
                    }
                }
            }
        }
        return all_cleared;
    }

    virtual bool SweepByMagic(ICXParam* xp, ulong magic) override {
        bool all_cleared = true;
        XP_LOG_WARN(xp, StringFormat("[EXIT-SWEEP-MAGIC] Starting Massive Sweep for Magic:%I64u", magic));
        
        //-- 포지션 스윕 (Magic 기준 전수 조사)
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong t = PositionGetTicket(i);
            if(PositionSelectByTicket(t)) {
                if(PositionGetInteger(POSITION_MAGIC) == (long)magic) {
                    XP_LOG_INFO(xp, StringFormat("[POS-CLOSE-SWEEP] Sending Bulk Request [Ticket:%I64u, M:%I64u]", t, magic));
                    if(!PositionClose(xp, t)) {
                        all_cleared = false;
                    }
                }
            }
        }
        //-- 주문 스윕 (Magic 기준 전수 조사)
        for(int i = OrdersTotal() - 1; i >= 0; i--) {
            ulong t = OrderGetTicket(i);
            if(OrderSelect(t)) {
                if(OrderGetInteger(ORDER_MAGIC) == (long)magic) {
                    XP_LOG_INFO(xp, StringFormat("[ORDER-DELETE-SWEEP] Sending Bulk Request [Ticket:%I64u, M:%I64u]", t, magic));
                    if(!OrderDelete(xp, t)) {
                        all_cleared = false;
                    }
                }
            }
        }
        return all_cleared;
    }

    //--- 4. 호환성 및 부가 유틸리티
    
    virtual ulong GetLastResultDeal() override { return m_trade.ResultDeal(); }
    virtual ulong GetLastResultOrder() override { return m_trade.ResultOrder(); }
    virtual uint  GetLastRetCode() override { return m_trade.ResultRetcode(); }
    virtual string GetLastRetCodeDescription() override { return m_trade.ResultRetcodeDescription(); }
};

#endif
