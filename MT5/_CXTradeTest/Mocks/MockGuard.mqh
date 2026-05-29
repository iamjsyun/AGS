#ifndef MOCKGUARD_MQH
#define MOCKGUARD_MQH

#include "..\..\Core\Interfaces\IXGuard.mqh"

/**
 * @class MockGuard
 * @brief IXGuard의 단위 테스트용 Mock 객체
 */
class MockGuard : public IXGuard {
private:
    bool m_validateLotReturn;
    bool m_validateSIDReturn;
public:
    MockGuard() : m_validateLotReturn(true), m_validateSIDReturn(true) {}
    
    void SetValidateLotReturn(bool val) { m_validateLotReturn = val; }
    void SetValidateSIDReturn(bool val) { m_validateSIDReturn = val; }
    
    virtual bool ValidateMagic(long magic) override { return true; }
    virtual bool ValidateSID(string sid) override { return m_validateSIDReturn; }
    virtual bool ValidateGID(string gid) override { return true; }
    virtual bool ValidatePrice(string symbol, double price) override { return true; }
    virtual bool ValidateLot(string symbol, double lot) override { return m_validateLotReturn; }
    virtual bool ValidateSlippage(int slippage) override { return true; }
    virtual double PointsToPrice(string symbol, double points) const override { return 0.0; }
    virtual double NormalizePrice(string symbol, double price) const override { return price; }
    virtual bool ValidateStopLevel(string symbol, double base_price, double target_price) override { return true; }
    virtual bool ValidateComment(string comment) override { return true; }
    virtual bool ValidateCnoBinding(int cno, long magic) override { return true; }
    virtual string GetLastError() const override { return "Mock Error"; }
    virtual bool Check(ICXParam* xp, ICXContext* ctx) override { return true; }
};

#endif