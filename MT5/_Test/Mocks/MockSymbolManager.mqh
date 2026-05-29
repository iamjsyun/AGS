#ifndef MOCK_SYMBOL_MANAGER_MQH
#define MOCK_SYMBOL_MANAGER_MQH

#include "..\..\Core\Interfaces\ICXSymbolManager.mqh"

/**
 * @class MockSymbolManager
 * @brief 테스트 환경을 위한 ICXSymbolManager 모의 객체
 */
class MockSymbolManager : public ICXSymbolManager {
public:
    MockSymbolManager() {}
    virtual ~MockSymbolManager() override {}

    virtual double GetPoint(string symbol) override { return 0.01; }
    virtual int    GetDigits(string symbol) override { return 2; }
    virtual double GetTickSize(string symbol) override { return 0.01; }
    virtual int    GetStopsLevel(string symbol) override { return 0; }
    virtual int    GetFreezeLevel(string symbol) override { return 0; }
    virtual double GetMinLot(string symbol) override { return 0.01; }
    virtual double GetMaxLot(string symbol) override { return 50.0; }
    virtual double GetLotStep(string symbol) override { return 0.01; }
    virtual int    GetSpread(string symbol) override { return 2; }
    virtual void   Refresh(string symbol) override {}
};

#endif
