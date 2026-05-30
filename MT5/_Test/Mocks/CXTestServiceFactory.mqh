//+------------------------------------------------------------------+
//|                                         CXTestServiceFactory.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Test Service Factory to inject mocks into AppService      |
//+------------------------------------------------------------------+
#ifndef CX_TEST_SERVICE_FACTORY_MQH
#define CX_TEST_SERVICE_FACTORY_MQH

#include "..\..\Service\App\CXServiceFactory.mqh"
#include "MockPriceManager.mqh"
#include "MockTerminalPlatform.mqh"
#include "MockSymbolManager.mqh"
#include "..\Scenarios\CXVirtualPricer.mqh"

/**
 * @class CXTestServiceFactory
 * @brief 테스트 환경용 서비스 팩토리로, MockPriceManager 및 MockTerminalPlatform을 의존성 주입함
 */
class CXTestServiceFactory : public CXServiceFactory {
private:
    CXVirtualPricer*      m_pricer;
    MockTerminalPlatform* m_mockTerminal;

public:
    CXTestServiceFactory(CXVirtualPricer* pricer, MockTerminalPlatform* terminal) 
        : m_pricer(pricer), m_mockTerminal(terminal) {}

    virtual ~CXTestServiceFactory() override {
        // Life of m_pricer and m_mockTerminal managed by runner
    }

    /**
     * @brief MockPriceManager 주입
     */
    virtual ICXPriceManager* CreatePriceManager(ICXContext* ctx) override {
        MockPriceManager* pm = new MockPriceManager(ctx);
        pm.SetPricer(m_pricer);
        return pm;
    }

    /**
     * @brief MockTerminalPlatform 주입
     */
    virtual IXTerminalPlatform* CreateTerminalPlatform(ICXContext* ctx) override {
        return m_mockTerminal;
    }

    /**
     * @brief MockSymbolManager 주입
     */
    virtual ICXSymbolManager* CreateSymbolManager(ICXContext* ctx) override {
        return new MockSymbolManager();
    }
};

#endif
