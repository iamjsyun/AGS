//+------------------------------------------------------------------+
//|                                             MockPriceManager.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Mock Price Manager wrapping CXVirtualPricer for Testing   |
//+------------------------------------------------------------------+
#ifndef MOCK_PRICE_MANAGER_MQH
#define MOCK_PRICE_MANAGER_MQH

#include "..\..\Engine\Price\CXPriceManager.mqh"
#include "..\Scenarios\CXVirtualPricer.mqh"

/**
 * @class MockPriceManager
 * @brief ICXPriceManager를 구현하고 가상 가격 생성기(CXVirtualPricer)와 바인딩되는 테스팅 전용 모의 객체
 */
class MockPriceManager : public CXPriceManager {
private:
    CXVirtualPricer* m_pricer;

    void DebugLog(string msg) {
        int h = FileOpen("debug_log.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
        if(h != INVALID_HANDLE) {
            FileSeek(h, 0, SEEK_END);
            FileWriteString(h, msg + "\r\n");
            FileClose(h);
        } else {
            Print("[DEBUGLOG-ERR] Failed to write debug_log.txt in MockPriceManager. Code: ", GetLastError());
        }
    }

public:
    MockPriceManager(ICXContext* ctx) : CXPriceManager(ctx), m_pricer(NULL) {}
    virtual ~MockPriceManager() {}

    /**
     * @brief 가상 가격 생성기 인스턴스를 설정
     */
    void SetPricer(CXVirtualPricer* pricer) {
        m_pricer = pricer;
        DebugLog("MockPriceManager::SetPricer called. Pricer valid: " + (string)(CheckPointer(m_pricer) != POINTER_INVALID));
    }

    /**
     * @brief 방향에 따른 가상 Ask/Bid 반환 (시장가)
     */
    virtual double GetMarketPrice(string symbol, int dir) override {
        DebugLog(StringFormat("MockPriceManager::GetMarketPrice(Sym:%s, Dir:%d) called", symbol, dir));
        if(CheckPointer(m_pricer) != POINTER_INVALID) {
            double ask = m_pricer.GetAsk();
            double bid = m_pricer.GetBid();
            double res = (dir == CX_DIR_BUY) ? ask : bid;
            DebugLog(StringFormat("MockPriceManager::GetMarketPrice - Virtual pricer returned: Ask:%.5f, Bid:%.5f -> Res:%.5f", ask, bid, res));
            return res;
        }
        double res = CXPriceManager::GetMarketPrice(symbol, dir);
        DebugLog(StringFormat("MockPriceManager::GetMarketPrice - Fallback CXPriceManager returned: %.5f", res));
        return res;
    }

    /**
     * @brief 방향에 따른 가상 청산 가격 반환
     */
    virtual double GetLiquidationPrice(string symbol, int dir) override {
        DebugLog(StringFormat("MockPriceManager::GetLiquidationPrice(Sym:%s, Dir:%d) called", symbol, dir));
        if(CheckPointer(m_pricer) != POINTER_INVALID) {
            double ask = m_pricer.GetAsk();
            double bid = m_pricer.GetBid();
            double res = (dir == CX_DIR_BUY) ? bid : ask;
            DebugLog(StringFormat("MockPriceManager::GetLiquidationPrice - Virtual pricer returned: Ask:%.5f, Bid:%.5f -> Res:%.5f", ask, bid, res));
            return res;
        }
        double res = CXPriceManager::GetLiquidationPrice(symbol, dir);
        DebugLog(StringFormat("MockPriceManager::GetLiquidationPrice - Fallback CXPriceManager returned: %.5f", res));
        return res;
    }
};

#endif
