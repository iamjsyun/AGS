#ifndef CXTERMINALPLATFORM_MQH
#define CXTERMINALPLATFORM_MQH

#include "..\..\01_Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\01_Core\Defines\CXDefine.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "Platform\CXHistoryAnalyzer.mqh"
#include <Trade\Trade.mqh>
#include <Arrays\ArrayLong.mqh>

/**
 * @class CXTerminalPlatform
 * @brief MT5 terminal and broker integration platform class (v11.1 Logging & MT5 API Encapsulation)
 * @details [v1.0 Subdivision] Delegate history analysis logic to CXHistoryAnalyzer
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

    //--- 1. Trade Execution (Trade Operations)
    
    virtual bool PositionOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override {
        if(IS_INVALID(sig)) return false;
        string symbol = sig.GetSymbol();
        double lot = sig.GetLot();
        int dir = sig.GetDir();
        ulong magic = sig.GetMagic();
        string sid = sig.GetSid();
        ENUM_ORDER_TYPE order_type = (dir == CX_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

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

    //--- 2. Account Information Inquiry (Account Information)
    virtual double GetAccountBalance() override { return AccountInfoDouble(ACCOUNT_BALANCE); }
    virtual double GetAccountEquity() override { return AccountInfoDouble(ACCOUNT_EQUITY); }
    virtual double GetAccountMargin() override { return AccountInfoDouble(ACCOUNT_MARGIN); }
    virtual double GetAccountFreeMargin() override { return AccountInfoDouble(ACCOUNT_MARGIN_FREE); }
    virtual long   GetAccountLeverage() override { return AccountInfoInteger(ACCOUNT_LEVERAGE); }

    //--- 3. Physical Asset Status Inquiry (Asset Queries)
    virtual bool IsPositionExists(ulong ticket) override { return (ticket > 0 && PositionSelectByTicket(ticket)); }
    virtual bool IsOrderExists(ulong ticket) override { return (ticket > 0 && OrderSelect(ticket)); }

    virtual double GetPositionVolume(ulong ticket) override { return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_VOLUME) : 0; }
    virtual double GetPositionPriceOpen(ulong ticket) override { return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_PRICE_OPEN) : 0; }
    virtual double GetOrderVolume(ulong ticket) override { return OrderSelect(ticket) ? OrderGetDouble(ORDER_VOLUME_CURRENT) : 0; }
    virtual double GetOrderPriceOpen(ulong ticket) override { return OrderSelect(ticket) ? OrderGetDouble(ORDER_PRICE_OPEN) : 0; }
    virtual double GetOrderSL(ulong ticket) override { return OrderSelect(ticket) ? OrderGetDouble(ORDER_SL) : 0; }
    virtual double GetOrderTP(ulong ticket) override { return OrderSelect(ticket) ? OrderGetDouble(ORDER_TP) : 0; }
    virtual int    GetPositionsTotal() override { return PositionsTotal(); }
    virtual int    GetOrdersTotal() override { return OrdersTotal(); }
    virtual double GetPositionSL(ulong ticket) override { return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_SL) : 0; }
    virtual double GetPositionTP(ulong ticket) override { return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_TP) : 0; }
    virtual double GetPositionProfit(ulong ticket) override { return PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_PROFIT) : 0.0; }
    virtual string GetPositionComment(ulong ticket) override { return PositionSelectByTicket(ticket) ? PositionGetString(POSITION_COMMENT) : ""; }
    virtual string GetOrderComment(ulong ticket) override { return OrderSelect(ticket) ? OrderGetString(ORDER_COMMENT) : ""; }

    /**
     * @brief [v1.0 Subdivision] Delegate history analysis logic to CXHistoryAnalyzer
     */
    virtual int CheckHistoryClosure(ulong ticket, string &outReason) override {
        CXHistoryAnalyzer analyzer(GetPointer(this));
        return analyzer.Analyze(ticket, outReason);
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
        
        CArrayLong posTickets;
        int totalPos = PositionsTotal();
        for(int i = 0; i < totalPos; i++) {
            ulong t = PositionGetTicket(i);
            if(PositionSelectByTicket(t)) {
                if(PositionGetInteger(POSITION_MAGIC) == (long)magic && PositionGetString(POSITION_COMMENT) == sid) posTickets.Add(t);
            }
        }

        CArrayLong ordTickets;
        int totalOrd = OrdersTotal();
        for(int i = 0; i < totalOrd; i++) {
            ulong t = OrderGetTicket(i);
            if(OrderSelect(t)) {
                if(OrderGetInteger(ORDER_MAGIC) == (long)magic && OrderGetString(ORDER_COMMENT) == sid) ordTickets.Add(t);
            }
        }

        for(int i = 0; i < posTickets.Total(); i++) {
            ulong t = posTickets.At(i);
            if(!PositionClose(xp, t)) all_cleared = false;
        }

        for(int i = 0; i < ordTickets.Total(); i++) {
            ulong t = ordTickets.At(i);
            if(!OrderDelete(xp, t)) all_cleared = false;
        }
        return all_cleared;
    }

    virtual bool SweepByMagic(ICXParam* xp, ulong magic) override {
        bool all_cleared = true;
        CArrayLong posTickets;
        int totalPos = PositionsTotal();
        for(int i = 0; i < totalPos; i++) {
            ulong t = PositionGetTicket(i);
            if(PositionSelectByTicket(t)) {
                if(PositionGetInteger(POSITION_MAGIC) == (long)magic) posTickets.Add(t);
            }
        }

        CArrayLong ordTickets;
        int totalOrd = OrdersTotal();
        for(int i = 0; i < totalOrd; i++) {
            ulong t = OrderGetTicket(i);
            if(OrderSelect(t)) {
                if(OrderGetInteger(ORDER_MAGIC) == (long)magic) ordTickets.Add(t);
            }
        }

        for(int i = 0; i < posTickets.Total(); i++) {
            ulong t = posTickets.At(i);
            if(!PositionClose(xp, t)) all_cleared = false;
        }

        for(int i = 0; i < ordTickets.Total(); i++) {
            ulong t = ordTickets.At(i);
            if(!OrderDelete(xp, t)) all_cleared = false;
        }
        return all_cleared;
    }

    //--- 4. Compatibility and Additional Utilities
    virtual ulong GetLastResultDeal() override { return m_trade.ResultDeal(); }
    virtual ulong GetLastResultOrder() override { return m_trade.ResultOrder(); }
    virtual uint  GetLastRetCode() override { return m_trade.ResultRetcode(); }
    virtual string GetLastRetCodeDescription() override { return m_trade.ResultRetcodeDescription(); }

    //--- 6. History Access (Internal Implementation)
    virtual bool HistorySelect(datetime from, datetime to) override { return ::HistorySelect(from, to); }
    virtual int  HistoryDealsTotal() override { return ::HistoryDealsTotal(); }
    virtual ulong HistoryDealGetTicket(int index) override { return ::HistoryDealGetTicket(index); }
    virtual long HistoryDealGetInteger(ulong ticket, int prop) override { return ::HistoryDealGetInteger(ticket, (ENUM_DEAL_PROPERTY_INTEGER)prop); }
    virtual string HistoryDealGetString(ulong ticket, int prop) override { return ::HistoryDealGetString(ticket, (ENUM_DEAL_PROPERTY_STRING)prop); }
    virtual int  HistoryOrdersTotal() override { return ::HistoryOrdersTotal(); }
    virtual ulong HistoryOrderGetTicket(int index) override { return ::HistoryOrderGetTicket(index); }
    virtual long HistoryOrderGetInteger(ulong ticket, int prop) override { return ::HistoryOrderGetInteger(ticket, (ENUM_ORDER_PROPERTY_INTEGER)prop); }
};

#endif
