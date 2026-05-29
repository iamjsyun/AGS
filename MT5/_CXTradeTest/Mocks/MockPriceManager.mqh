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

public:
    MockPriceManager(ICXContext* ctx) : CXPriceManager(ctx), m_pricer(NULL) {}
    virtual ~MockPriceManager() {}

    /**
     * @brief 가상 가격 생성기 인스턴스를 설정
     */
    void SetPricer(CXVirtualPricer* pricer) {
        m_pricer = pricer;
    }

    /**
     * @brief 방향에 따른 가상 Ask/Bid 반환 (시장가)
     */
    virtual double GetMarketPrice(string symbol, int dir) override {
        if(CheckPointer(m_pricer) != POINTER_INVALID) {
            return (dir == CX_DIR_BUY) ? m_pricer.GetAsk() : m_pricer.GetBid();
        }
        return CXPriceManager::GetMarketPrice(symbol, dir);
    }

    /**
     * @brief 방향에 따른 가상 청산 가격 반환
     */
    virtual double GetLiquidationPrice(string symbol, int dir) override {
        if(CheckPointer(m_pricer) != POINTER_INVALID) {
            return (dir == CX_DIR_BUY) ? m_pricer.GetBid() : m_pricer.GetAsk();
        }
        return CXPriceManager::GetLiquidationPrice(symbol, dir);
    }
};

#endif
