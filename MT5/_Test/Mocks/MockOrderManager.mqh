#ifndef MOCKORDERMANAGER_MQH
#define MOCKORDERMANAGER_MQH

#include "..\..\Core\Interfaces\IXOrderManager.mqh"

/**
 * @class MockOrderManager
 * @brief 테스트 환경을 위한 IXOrderManager 모의 객체
 */
class MockOrderManager : public IXOrderManager {
private:
    bool m_executeResult;
public:
    MockOrderManager() : m_executeResult(true) {}
    virtual ~MockOrderManager() override {}

    void SetExecuteResult(bool result) { m_executeResult = result; }

    virtual void SetMagic(ulong magic) override {}
    virtual void Pulse(ICXParam* xp) override {}
    virtual bool ExecuteEntry(ICXParam* xp) override { return m_executeResult; }
    virtual bool ExecuteExit(ICXParam* xp) override { return true; }
    virtual bool ModifyOrder(ICXParam* xp, ulong ticket, double price, double sl, double tp) override { return true; }
    virtual bool ModifyPosition(ICXParam* xp, ulong ticket, double sl, double tp) override { return true; }
    virtual bool DeleteOrder(ICXParam* xp, ulong ticket) override { return true; }
    virtual void ScanAndBind(ICXParam* xp, CObject* sessionMgr) override {}
    
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") override { return ""; }
};

#endif
