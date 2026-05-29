//+------------------------------------------------------------------+
//|                                         MockTerminalPlatform.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Mock Terminal Platform to simulate broker/MT5 actions     |
//+------------------------------------------------------------------+
#ifndef MOCK_TERMINAL_PLATFORM_MQH
#define MOCK_TERMINAL_PLATFORM_MQH

#include "..\..\Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\Core\Interfaces\ICXContext.mqh"
#include "..\..\Core\Defines\CXDefine.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Logger\CXAuditFormatter.mqh"
#include <Arrays\ArrayObj.mqh>

/**
 * @class MockAsset
 * @brief 모의 주문 및 포지션 데이터를 관리하기 위한 구조체
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
 * @class MockHistory
 * @brief 모의 과거 청산 이력을 관리하기 위한 구조체
 */
class MockHistory : public CObject {
public:
    ulong  ticket;
    string reason;
    int    closeStatus;

    MockHistory() : ticket(0), reason(""), closeStatus(0) {}
};

/**
 * @class MockTerminalPlatform
 * @brief 브로커 서버 및 MT5 API 호출을 로컬 인메모리 리스트로 가로채 시뮬레이션하는 모의 클래스
 */
class MockTerminalPlatform : public IXTerminalPlatform {
private:
    ulong      m_nextTicket;
    ulong      m_lastResultDeal;
    ulong      m_lastResultOrder;
    uint       m_lastRetCode;
    bool       m_failNextTrade;
    CArrayObj* m_assets;
    CArrayObj* m_history;

public:
    MockTerminalPlatform() : m_nextTicket(50001), m_lastResultDeal(0), m_lastResultOrder(0), m_lastRetCode(10009), m_failNextTrade(false) {
        m_assets = new CArrayObj();
        m_history = new CArrayObj();
    }

    virtual ~MockTerminalPlatform() override {
        if(CheckPointer(m_assets) == POINTER_DYNAMIC) delete m_assets;
        if(CheckPointer(m_history) == POINTER_DYNAMIC) delete m_history;
    }

    //--- Helper to access mock assets directly for verification
    CArrayObj* GetAssets() { return m_assets; }
    CArrayObj* GetHistory() { return m_history; }
    void SetFailNextTrade(bool fail) { m_failNextTrade = fail; }

    /**
     * @brief 강제로 특정 자산 상태를 터미널 환경에 수동 주입 (TCL INJECT: terminal 대응)
     */
    void InjectMockAsset(bool order_fill, ulong ticket, string sid, string symbol, int magic, int dir, double lot, double price, double sl, double tp) {
        // 이미 해당 ticket이나 sid를 가진 자산이 존재하면 삭제
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.sid == sid || (ticket > 0 && asset.ticket == ticket)) {
                m_assets.Delete(i);
            }
        }

        if(order_fill) {
            // 포지션으로 주입
            MockAsset* asset = new MockAsset();
            asset.ticket = (ticket > 0) ? ticket : m_nextTicket++;
            asset.sid = sid;
            asset.symbol = symbol;
            asset.magic = magic;
            asset.lot = lot;
            asset.dir = dir;
            asset.type = (dir == CX_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            asset.price = price;
            asset.sl = sl;
            asset.tp = tp;
            asset.is_position = true;
            asset.comment = sid;
            m_assets.Add(asset);
            PrintFormat("[MOCK-TERM] Injected Position: Ticket:%I64u, SID:%s, Lot:%.2f, Price:%.5f", asset.ticket, sid, lot, price);
        } else {
            // ticket > 0 인데 order_fill=false 라면, 해당 ticket을 강제 청산(역사 기록) 처리하여 자산 증발을 모의
            if(ticket > 0) {
                MockHistory* hist = new MockHistory();
                hist.ticket = ticket;
                hist.reason = "Closed by Manual (MOCK)";
                hist.closeStatus = XE_CLOSED_MANUAL;
                m_history.Add(hist);
                PrintFormat("[MOCK-TERM] Injected Manual Exit History for Ticket:%I64u", ticket);
            }
        }
    }

    /**
     * @brief 가상 가격 생성기의 Bid/Ask에 의한 손절/익절 브로커 트리거
     */
    void UpdateBrokerTriggeredExits(string symbol, double bid, double ask) {
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.symbol != symbol) continue;

            bool triggered = false;
            int status = XE_UNKNOWN;
            string reason = "";

            if(asset.is_position) {
                if(asset.dir == CX_DIR_BUY) {
                    if(asset.sl > 0 && bid <= asset.sl) {
                        triggered = true;
                        status = XE_CLOSED_SL;
                        reason = "sl [sl]";
                    } else if(asset.tp > 0 && bid >= asset.tp) {
                        triggered = true;
                        status = XE_CLOSED_TP;
                        reason = "tp [tp]";
                    }
                } else { // SELL
                    if(asset.sl > 0 && ask >= asset.sl) {
                        triggered = true;
                        status = XE_CLOSED_SL;
                        reason = "sl [sl]";
                    } else if(asset.tp > 0 && ask <= asset.tp) {
                        triggered = true;
                        status = XE_CLOSED_TP;
                        reason = "tp [tp]";
                    }
                }
            } else {
                // 대기주문 체결 확인 (Limit/Stop 체결)
                // Buy Limit: ask <= price
                // Sell Limit: bid >= price
                if(asset.type == ORDER_TYPE_BUY_LIMIT) {
                    if(ask <= asset.price) {
                        // 체결: 대기 오더를 포지션으로 전환
                        asset.is_position = true;
                        asset.price = ask; // 체결가
                        PrintFormat("[MOCK-BROKER] Pending BUY_LIMIT ticket %I64u filled at %.5f", asset.ticket, ask);
                    }
                } else if(asset.type == ORDER_TYPE_SELL_LIMIT) {
                    if(bid >= asset.price) {
                        // 체결
                        asset.is_position = true;
                        asset.price = bid; // 체결가
                        PrintFormat("[MOCK-BROKER] Pending SELL_LIMIT ticket %I64u filled at %.5f", asset.ticket, bid);
                    }
                }
            }

            if(triggered) {
                MockHistory* hist = new MockHistory();
                hist.ticket = asset.ticket;
                hist.reason = reason;
                hist.closeStatus = status;
                m_history.Add(hist);

                PrintFormat("[MOCK-BROKER] Position Ticket %I64u closed by SL/TP. Reason: %s", asset.ticket, reason);
                m_assets.Delete(i);
            }
        }
    }

    virtual void SetMagic(ulong magic) override {}

    virtual bool PositionOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override {
        if(IS_INVALID(sig)) return false;
        MockAsset* asset = new MockAsset();
        asset.ticket = m_nextTicket++;
        asset.sid = sig.GetSid();
        asset.symbol = sig.GetSymbol();
        asset.magic = (int)sig.GetMagic();
        asset.lot = sig.GetLot();
        asset.dir = sig.GetDir();
        asset.type = sig.GetType();
        asset.price = price;
        asset.sl = sl;
        asset.tp = tp;
        asset.is_position = true;
        asset.comment = sig.GetSid();
        m_assets.Add(asset);

        m_lastResultDeal = asset.ticket;
        m_lastResultOrder = asset.ticket;
        m_lastRetCode = 10009; // DONE

        XP_LOG_OK(xp, StringFormat("[EXEC-ENTRY] Sending Order (MOCK): [Sym:%s, Type:%s, Lot:%.2f, Price:%.5f, SL:%.5f, TP:%.5f, SID:%s]",
                                   asset.symbol, (asset.dir == CX_DIR_BUY) ? "BUY" : "SELL", asset.lot, price, sl, tp, asset.sid));
        return true;
    }

    virtual bool OrderOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) override {
        if(IS_INVALID(sig)) return false;
        MockAsset* asset = new MockAsset();
        asset.ticket = m_nextTicket++;
        asset.sid = sig.GetSid();
        asset.symbol = sig.GetSymbol();
        asset.magic = (int)sig.GetMagic();
        asset.lot = sig.GetLot();
        asset.dir = sig.GetDir();
        asset.type = (sig.GetDir() == CX_DIR_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        asset.price = price;
        asset.sl = sl;
        asset.tp = tp;
        asset.is_position = false;
        asset.comment = sig.GetSid();
        m_assets.Add(asset);

        m_lastResultOrder = asset.ticket;
        m_lastRetCode = 10009; // DONE

        XP_LOG_OK(xp, StringFormat("[EXEC-ENTRY] Sending Order (MOCK): [Sym:%s, Type:%s, Lot:%.2f, Price:%.5f, SL:%.5f, TP:%.5f, SID:%s]",
                                   asset.symbol, (asset.dir == CX_DIR_BUY) ? "BUY_LIMIT" : "SELL_LIMIT", asset.lot, price, sl, tp, asset.sid));
        return true;
    }

    virtual bool PositionModify(ICXParam* xp, ulong ticket, double sl, double tp) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) {
                asset.sl = sl;
                asset.tp = tp;
                m_lastRetCode = 10009;
                XP_LOG_OK(xp, StringFormat("[POS-MODIFY] Sending Request (MOCK): [Ticket:%I64u, SL:%.5f, TP:%.5f]", ticket, sl, tp));
                return true;
            }
        }
        return false;
    }

    virtual bool OrderModify(ICXParam* xp, ulong ticket, double price, double sl, double tp) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) {
                asset.price = price;
                asset.sl = sl;
                asset.tp = tp;
                m_lastRetCode = 10009;
                XP_LOG_OK(xp, StringFormat("[ORDER-MODIFY] Sending Request (MOCK): [Ticket:%I64u, Price:%.5f, SL:%.5f, TP:%.5f]", ticket, price, sl, tp));
                return true;
            }
        }
        return false;
    }

    virtual bool PositionClose(ICXParam* xp, ulong ticket) override {
        if(m_failNextTrade) {
            m_lastRetCode = 10013; // Invalid request or broker error
            XP_LOG_ERROR(xp, StringFormat("[ORDER-DELETE-FAIL] Broker Code:%u(Mock Error). Raw: [Ticket:%I64u] (PositionClose)", m_lastRetCode, ticket));
            m_failNextTrade = false; // Reset after one failure
            return false;
        }
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) {
                MockHistory* hist = new MockHistory();
                hist.ticket = ticket;
                hist.reason = "Closed by Signal (MOCK)";
                hist.closeStatus = XE_CLOSED_SIGNAL;
                m_history.Add(hist);

                m_assets.Delete(i);
                m_lastRetCode = 10009;
                XP_LOG_OK(xp, StringFormat("[ORDER-DELETE] Sending Request (MOCK): [Ticket:%I64u] (PositionClose)", ticket));
                return true;
            }
        }
        return false;
    }

    virtual bool OrderDelete(ICXParam* xp, ulong ticket) override {
        if(m_failNextTrade) {
            m_lastRetCode = 10013;
            XP_LOG_ERROR(xp, StringFormat("[ORDER-DELETE-FAIL] Broker Code:%u(Mock Error). Raw: [Ticket:%I64u]", m_lastRetCode, ticket));
            m_failNextTrade = false;
            return false;
        }
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) {
                MockHistory* hist = new MockHistory();
                hist.ticket = ticket;
                hist.reason = "Canceled (MOCK)";
                hist.closeStatus = XE_CLOSED_SIGNAL;
                m_history.Add(hist);

                m_assets.Delete(i);
                m_lastRetCode = 10009;
                XP_LOG_OK(xp, StringFormat("[ORDER-DELETE] Sending Request (MOCK): [Ticket:%I64u]", ticket));
                return true;
            }
        }
        return false;
    }

    virtual double GetAccountBalance() override { return 10000.0; }
    virtual double GetAccountEquity() override { return 10000.0; }
    virtual double GetAccountMargin() override { return 0.0; }
    virtual double GetAccountFreeMargin() override { return 10000.0; }
    virtual long   GetAccountLeverage() override { return 100; }

    virtual bool IsPositionExists(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return true;
        }
        return false;
    }

    virtual bool IsOrderExists(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) return true;
        }
        return false;
    }

    virtual double GetPositionVolume(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return asset.lot;
        }
        return 0;
    }

    virtual double GetPositionPriceOpen(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return asset.price;
        }
        return 0;
    }

    virtual double GetPositionSL(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return asset.sl;
        }
        return 0;
    }

    virtual double GetPositionTP(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return asset.tp;
        }
        return 0;
    }

    virtual double GetOrderVolume(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) return asset.lot;
        }
        return 0;
    }

    virtual double GetOrderPriceOpen(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) return asset.price;
        }
        return 0;
    }

    virtual double GetOrderSL(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) return asset.sl;
        }
        return 0;
    }

    virtual double GetOrderTP(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) return asset.tp;
        }
        return 0;
    }

    virtual int GetPositionsTotal() override {
        int count = 0;
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.is_position) count++;
        }
        return count;
    }

    virtual int GetOrdersTotal() override {
        int count = 0;
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(!asset.is_position) count++;
        }
        return count;
    }

    virtual double GetPositionProfit(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return asset.profit;
        }
        return 0;
    }

    virtual string GetPositionComment(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && asset.is_position) return asset.comment;
        }
        return "";
    }

    virtual string GetOrderComment(ulong ticket) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.ticket == ticket && !asset.is_position) return asset.comment;
        }
        return "";
    }

    virtual int CheckHistoryClosure(ulong ticket, string &outReason) override {
        for(int i = 0; i < m_history.Total(); i++) {
            MockHistory* hist = (MockHistory*)m_history.At(i);
            if(hist.ticket == ticket) {
                outReason = hist.reason;
                return hist.closeStatus;
            }
        }
        outReason = "Not found in mock history";
        return XE_UNKNOWN;
    }

    virtual bool VerifyPhysicalAbsence(ulong magic, string sid) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.magic == (int)magic && asset.sid == sid) return false;
        }
        return true;
    }

    virtual ulong GetTicketBySid(ulong magic, string sid) override {
        for(int i = 0; i < m_assets.Total(); i++) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.magic == (int)magic && asset.sid == sid) return asset.ticket;
        }
        return 0;
    }

    virtual bool SweepBySid(ICXParam* xp, ulong magic, string sid) override {
        bool all_cleared = true;
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.magic == (int)magic && asset.sid == sid) {
                MockHistory* hist = new MockHistory();
                hist.ticket = asset.ticket;
                hist.reason = "Sweep (MOCK)";
                hist.closeStatus = XE_CLOSED_SIGNAL;
                m_history.Add(hist);

                m_assets.Delete(i);
            }
        }
        return all_cleared;
    }

    virtual bool SweepByMagic(ICXParam* xp, ulong magic) override {
        bool all_cleared = true;
        for(int i = m_assets.Total() - 1; i >= 0; i--) {
            MockAsset* asset = (MockAsset*)m_assets.At(i);
            if(asset.magic == (int)magic) {
                MockHistory* hist = new MockHistory();
                hist.ticket = asset.ticket;
                hist.reason = "Magic Sweep (MOCK)";
                hist.closeStatus = XE_CLOSED_SIGNAL;
                m_history.Add(hist);

                m_assets.Delete(i);
            }
        }
        return all_cleared;
    }

    virtual ulong GetLastResultDeal() override { return m_lastResultDeal; }
    virtual ulong GetLastResultOrder() override { return m_lastResultOrder; }
    virtual uint  GetLastRetCode() override { return m_lastRetCode; }
    virtual string GetLastRetCodeDescription() override { return "Mock OK"; }
};

#endif
