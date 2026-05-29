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

/**
 * @class CXTestServiceFactory
 * @brief 테스트 환경용 서비스 팩토리로, MockPriceManager 및 MockTerminalPlatform을 의존성 주입함
 */
class CXTestServiceFactory : public CXServiceFactory {
private:
    MockPriceManager*     m_mockPriceMgr;
    MockTerminalPlatform* m_mockTerminal;

public:
    CXTestServiceFactory(MockPriceManager* priceMgr, MockTerminalPlatform* terminal) 
        : m_mockPriceMgr(priceMgr), m_mockTerminal(terminal) {}

    virtual ~CXTestServiceFactory() override {
        // AppService가 m_priceManager와 m_terminalPlatform의 소유권을 가져가 해제하므로,
        // 이중 해제(Double Free) 방지를 위해 여기서는 삭제하지 않음
    }

    /**
     * @brief MockPriceManager 주입
     */
    virtual ICXPriceManager* CreatePriceManager(ICXContext* ctx) override {
        return m_mockPriceMgr;
    }

    /**
     * @brief MockTerminalPlatform 주입
     */
    virtual IXTerminalPlatform* CreateTerminalPlatform(ICXContext* ctx) override {
        return m_mockTerminal;
    }
};

#endif
