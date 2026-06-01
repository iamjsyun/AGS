//+------------------------------------------------------------------+
//|                                             MockPriceManager.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.1] Mock Price Manager with Fixed Fallback Price support      |
//+------------------------------------------------------------------+
#ifndef MOCK_PRICE_MANAGER_MQH
#define MOCK_PRICE_MANAGER_MQH

#include "..\..\03_Platform\Price\CXPriceManager.mqh"
#include "..\Scenarios\CXVirtualPricer.mqh"

/**
 * @class MockPriceManager
 * @brief Test-only mock object that implements ICXPriceManager and binds with CXVirtualPricer
 */
class MockPriceManager : public CXPriceManager {
private:
    CXVirtualPricer* m_pricer;
    double           m_fixed_ask;
    double           m_fixed_bid;

public:
    MockPriceManager(ICXContext* ctx) : CXPriceManager(ctx), m_pricer(NULL), m_fixed_ask(0), m_fixed_bid(0) {}
    virtual ~MockPriceManager() {}

    /**
     * @brief Set fixed base price (used when Pricer is not available)
     */
    void SetFixedPrice(double ask, double bid) {
        m_fixed_ask = ask;
        m_fixed_bid = bid;
    }

    /**
     * @brief Set virtual price generator instance
     */
    void SetPricer(CXVirtualPricer* pricer) {
        m_pricer = pricer;
    }

    /**
     * @brief Returns virtual Ask/Bid based on direction (market price)
     */
    virtual double GetMarketPrice(string symbol, int dir) override {
        if(CheckPointer(m_pricer) != POINTER_INVALID) {
            return (dir == CX_DIR_BUY) ? m_pricer.GetAsk() : m_pricer.GetBid();
        }
        if(m_fixed_ask > 0) {
            return (dir == CX_DIR_BUY) ? m_fixed_ask : m_fixed_bid;
        }
        return CXPriceManager::GetMarketPrice(symbol, dir);
    }

    /**
     * @brief Returns virtual liquidation price based on direction
     */
    virtual double GetLiquidationPrice(string symbol, int dir) override {
        if(CheckPointer(m_pricer) != POINTER_INVALID) {
            return (dir == CX_DIR_BUY) ? m_pricer.GetBid() : m_pricer.GetAsk();
        }
        if(m_fixed_ask > 0) {
            return (dir == CX_DIR_BUY) ? m_fixed_bid : m_fixed_ask;
        }
        return CXPriceManager::GetLiquidationPrice(symbol, dir);
    }
};

#endif
