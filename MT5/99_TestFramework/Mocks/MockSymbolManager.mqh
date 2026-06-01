#ifndef MOCK_SYMBOL_MANAGER_MQH
#define MOCK_SYMBOL_MANAGER_MQH

#include "..\..\01_Core\Interfaces\ICXSymbolManager.mqh"

/**
 * @class MockSymbolManager
 * @brief Mock object for ICXSymbolManager for test environment
 */
class MockSymbolManager : public ICXSymbolManager {
private:
    int    m_stops_level;
    double m_point;
public:
    MockSymbolManager() : m_stops_level(0), m_point(0.01) {}
    virtual ~MockSymbolManager() override {}

    void SetStopsLevel(int level) { m_stops_level = level; }
    void SetPoint(string symbol, double pt) { m_point = pt; }

    virtual double GetPoint(string symbol) override { return m_point; }
    virtual int    GetDigits(string symbol) override { return 2; }
    virtual double GetTickSize(string symbol) override { return 0.01; }
    virtual int    GetStopsLevel(string symbol) override { return m_stops_level; }
    virtual int    GetFreezeLevel(string symbol) override { return 0; }
    virtual double GetMinLot(string symbol) override { return 0.01; }
    virtual double GetMaxLot(string symbol) override { return 50.0; }
    virtual double GetLotStep(string symbol) override { return 0.01; }
    virtual int    GetSpread(string symbol) override { return 2; }
    virtual void   Refresh(string symbol) override {}
};

#endif
