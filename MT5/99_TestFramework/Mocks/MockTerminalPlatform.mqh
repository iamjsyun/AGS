//+------------------------------------------------------------------+
//|                                         MockTerminalPlatform.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.2] Mock Terminal Platform with History & Virtual World Support|
//+------------------------------------------------------------------+
#ifndef MOCK_TERMINAL_PLATFORM_MQH
#define MOCK_TERMINAL_PLATFORM_MQH

#include "..\..\01_Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\01_Core\Defines\CXDefine.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include <Arrays\ArrayObj.mqh>
#include <Trade\Trade.mqh>

/**
 * @class MockAsset
 * @brief Structure for managing simulated order and position data
 */
class MockAsset : public CObject {
public:
    ulong  ticket;
    string sid;
    string symbol;
    int    magic;
    double lot;
    int    dir;
    int    type;
    double price;
    double sl;
    double tp;
    bool   is_position;
    string comment;
    double profit;

    MockAsset() : ticket(0), sid(""), symbol(""), magic(0), lot(0.0), dir(0), type(0), 
                  price(0.0), sl(0.0), tp(0.0), is_position(false), comment(""), profit(0.0) {}
};

/**
 * @class MockHistoryDeal
 * @brief Simulated historical deal records
 */
class MockHistoryDeal : public CObject {
public:
    ulong  ticket;
    long   position_id;
    int    entry;
    string comment;
};

/**
 * @class MockHistoryOrder
 * @brief Simulated historical order records
 */
class MockHistoryOrder : public CObject {
public:
    ulong ticket;
    int   state;
};

/**
 * @class MockTerminalPlatform
 * @brief Mock class simulating MT5 API calls (Subdivision Phase 1 Support)
 */
class MockTerminalPlatform : public IXTerminalPlatform {
private:
    ulong      m_nextTicket;
    ulong      m_lastResultDeal;
    ulong      m_lastResultOrder;
    uint       m_lastRetCode;
    bool       m_failNextTrade;
    CArrayObj* m_assets;
    CArrayObj* m_historyDeals;
    CArrayObj* m_historyOrders;

public:
    MockTerminalPlatform() : m_nextTicket(50001), m_lastResultDeal(0), m_lastResultOrder(0), m_lastRetCode(10009), m_failNextTrade(false) {
        m_assets = new CArrayObj();
        m_historyDeals = new CArrayObj();
        m_historyOrders = new CArrayObj();
    }

    virtual ~MockTerminalPlatform() override {
        SAFE_DELETE(m_assets);
        SAFE_DELETE(m_historyDeals);
        SAFE_DELETE(m_historyOrders);
    }

    CArrayObj* GetAssets() { return m_assets; }
    void SetFailNextTrade(bool fail) { m_failNextTrade = fail; }
    virtual bool IsMock() override { return true; }

    void InjectMockAsset(bool order_fill, ulong ticket, string sid, string symbol, int magic, int dir, double lot, double price, double sl, double tp) {
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.sid == sid || (ticket > 0 && asset.ticket == ticket)) m_assets.Delete(i);
        }
        MockAsset* asset = new MockAsset();
        asset.ticket = (ticket > 0) ? ticket : m_nextTicket++;
        asset.sid = sid; asset.symbol = symbol; asset.magic = magic; asset.lot = lot; asset.dir = dir;
        asset.type = order_fill ? ((dir == CX_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL) : ((dir == CX_DIR_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);
        asset.price = price; asset.sl = sl; asset.tp = tp; asset.is_position = order_fill; asset.comment = sid;
        m_assets.Add(asset);
    }

    void InjectMockHistoryDeal(ulong ticket, long posId, int entry, string comment) {
        MockHistoryDeal* deal = new MockHistoryDeal();
        deal.ticket = ticket; deal.position_id = posId; deal.entry = entry; deal.comment = comment;
        m_historyDeals.Add(deal);
    }

    void InjectMockHistoryOrder(ulong ticket, int state) {
        MockHistoryOrder* ord = new MockHistoryOrder();
        ord.ticket = ticket; ord.state = state;
        m_historyOrders.Add(ord);
    }

    //--- Virtual World Engine (for Scenario Runner) ---
    void UpdateBrokerTriggeredExits(string symbol, double bid, double ask) {
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* a = (MockAsset*)m_assets.At(i);
            if(!a.is_position || a.symbol != symbol) continue;
            bool closed = false; string reason = "";
            if(a.dir == CX_DIR_BUY) {
                if(a.sl > 0 && bid <= a.sl) { closed = true; reason = "sl triggered [sl]"; }
                else if(a.tp > 0 && bid >= a.tp) { closed = true; reason = "tp triggered [tp]"; }
            } else {
                if(a.sl > 0 && ask >= a.sl) { closed = true; reason = "sl triggered [sl]"; }
                else if(a.tp > 0 && ask <= a.tp) { closed = true; reason = "tp triggered [tp]"; }
            }
            if(closed) {
                InjectMockHistoryDeal(a.ticket + 1000, (long)a.ticket, DEAL_ENTRY_OUT, reason);
                m_assets.Delete(i);
            }
        }
    }

    void UpdateBrokerTriggeredFills(string symbol, double bid, double ask) {
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* a = (MockAsset*)m_assets.At(i);
            if(a.is_position || a.symbol != symbol) continue;
            bool filled = false;
            if(a.type == ORDER_TYPE_BUY_LIMIT && ask <= a.price) filled = true;
            else if(a.type == ORDER_TYPE_SELL_LIMIT && bid >= a.price) filled = true;
            if(filled) a.is_position = true;
        }
    }

    //--- IXTerminalPlatform Implementation ---
    virtual void SetMagic(ulong magic) override {}
    virtual bool PositionOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override { 
        if(m_failNextTrade) { m_lastRetCode = 10015; return false; }
        ulong t = m_nextTicket++; m_lastResultOrder = t; sig.SetTicket(t);
        InjectMockAsset(true, t, sig.GetSid(), sig.GetSymbol(), (int)sig.GetMagic(), sig.GetDir(), sig.GetLot(), price, sl, tp);
        return true; 
    }
    virtual bool OrderOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override {
        if(m_failNextTrade) { m_lastRetCode = 10015; return false; }
        ulong t = m_nextTicket++; m_lastResultOrder = t; sig.SetTicket(t);
        InjectMockAsset(false, t, sig.GetSid(), sig.GetSymbol(), (int)sig.GetMagic(), sig.GetDir(), sig.GetLot(), price, sl, tp);
        return true;
    }
    virtual bool PositionModify(ICXParam* xp, ulong ticket, double sl, double tp) override { 
        for(int i=0; i<m_assets.Total(); i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket == ticket) { a.sl = sl; a.tp = tp; return true; } }
        return false;
    }
    virtual bool OrderModify(ICXParam* xp, ulong ticket, double price, double sl, double tp) override { 
        for(int i=0; i<m_assets.Total(); i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket == ticket) { a.price = price; a.sl = sl; a.tp = tp; return true; } }
        return false;
    }
    virtual bool PositionClose(ICXParam* xp, ulong ticket) override {
        for(int i=0; i<m_assets.Total(); i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket == ticket) { InjectMockHistoryDeal(ticket+1000, (long)ticket, DEAL_ENTRY_OUT, "manual close"); m_assets.Delete(i); return true; } }
        return false;
    }
    virtual bool OrderDelete(ICXParam* xp, ulong ticket) override {
        for(int i=0; i<m_assets.Total(); i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket == ticket) { InjectMockHistoryOrder(ticket, ORDER_STATE_CANCELED); m_assets.Delete(i); return true; } }
        return false;
    }

    virtual double GetAccountBalance() override { return 10000; }
    virtual double GetAccountEquity() override { return 10000; }
    virtual double GetAccountMargin() override { return 0; }
    virtual double GetAccountFreeMargin() override { return 10000; }
    virtual long   GetAccountLeverage() override { return 100; }

    virtual bool IsPositionExists(ulong ticket) override { 
        for(int i=0; i<m_assets.Total(); i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket == ticket && a.is_position) return true; }
        return false;
    }
    virtual bool IsOrderExists(ulong ticket) override {
        for(int i=0; i<m_assets.Total(); i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket == ticket && !a.is_position) return true; }
        return false;
    }
    virtual double GetPositionVolume(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.lot; } return 0; }
    virtual double GetPositionPriceOpen(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.price; } return 0; }
    virtual double GetPositionSL(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.sl; } return 0; }
    virtual double GetPositionTP(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.tp; } return 0; }
    virtual double GetOrderVolume(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.lot; } return 0; }
    virtual double GetOrderPriceOpen(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.price; } return 0; }
    virtual double GetOrderSL(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.sl; } return 0; }
    virtual double GetOrderTP(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.tp; } return 0; }
    virtual int    GetPositionsTotal() override { int c=0; for(int i=0;i<m_assets.Total();i++) if(((MockAsset*)m_assets.At(i)).is_position) c++; return c; }
    virtual int    GetOrdersTotal() override { int c=0; for(int i=0;i<m_assets.Total();i++) if(!((MockAsset*)m_assets.At(i)).is_position) c++; return c; }
    virtual double GetPositionProfit(ulong ticket) override { return 0; }
    virtual string GetPositionComment(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.comment; } return ""; }
    virtual string GetOrderComment(ulong ticket) override { for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.ticket==ticket) return a.comment; } return ""; }

    virtual int CheckHistoryClosure(ulong ticket, string &outReason) override { 
        return XE_UNKNOWN; // Handled by analyzer in real platform, mock uses analyzer too if needed
    }
    virtual bool VerifyPhysicalAbsence(ulong magic, string sid) override { 
        for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.magic == (int)magic && a.sid == sid) return false; }
        return true;
    }
    virtual ulong GetTicketBySid(ulong magic, string sid) override {
        for(int i=0;i<m_assets.Total();i++) { MockAsset* a = (MockAsset*)m_assets.At(i); if(a.magic == (int)magic && a.sid == sid) return a.ticket; }
        return 0;
    }
    virtual bool SweepBySid(ICXParam* xp, ulong magic, string sid) override { return true; }
    virtual bool SweepByMagic(ICXParam* xp, ulong magic) override { return true; }
    
    virtual ulong GetLastResultDeal() override { return m_lastResultDeal; }
    virtual ulong GetLastResultOrder() override { return m_lastResultOrder; }
    virtual uint  GetLastRetCode() override { return m_lastRetCode; }
    virtual string GetLastRetCodeDescription() override { return "Success"; }

    //--- History Access Implementation ---
    virtual bool HistorySelect(datetime from, datetime to) override { return true; }
    virtual int  HistoryDealsTotal() override { return m_historyDeals.Total(); }
    virtual ulong HistoryDealGetTicket(int index) override { MockHistoryDeal* d = (MockHistoryDeal*)m_historyDeals.At(index); return d?d.ticket:0; }
    virtual long HistoryDealGetInteger(ulong ticket, int prop) override {
        for(int i=0;i<m_historyDeals.Total();i++) {
            MockHistoryDeal* d = (MockHistoryDeal*)m_historyDeals.At(i);
            if(d.ticket == ticket) {
                if(prop == DEAL_POSITION_ID) return d.position_id;
                if(prop == DEAL_ENTRY) return d.entry;
            }
        }
        return 0;
    }
    virtual string HistoryDealGetString(ulong ticket, int prop) override {
        for(int i=0;i<m_historyDeals.Total();i++) {
            MockHistoryDeal* d = (MockHistoryDeal*)m_historyDeals.At(i);
            if(d.ticket == ticket && prop == DEAL_COMMENT) return d.comment;
        }
        return "";
    }
    virtual int  HistoryOrdersTotal() override { return m_historyOrders.Total(); }
    virtual ulong HistoryOrderGetTicket(int index) override { MockHistoryOrder* o = (MockHistoryOrder*)m_historyOrders.At(index); return o?o.ticket:0; }
    virtual long HistoryOrderGetInteger(ulong ticket, int prop) override {
        for(int i=0;i<m_historyOrders.Total();i++) {
            MockHistoryOrder* o = (MockHistoryOrder*)m_historyOrders.At(i);
            if(o.ticket == ticket && prop == ORDER_STATE) return o.state;
        }
        return 0;
    }
};

#endif
