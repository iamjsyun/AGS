//+------------------------------------------------------------------+
//|                                          MockPositionManager.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Mock Position Manager for task-level unit testing         |
//+------------------------------------------------------------------+
#ifndef MOCK_POSITION_MANAGER_MQH
#define MOCK_POSITION_MANAGER_MQH

#include "..\..\Core\Interfaces\IXPositionManager.mqh"

/**
 * @class MockPositionManager
 * @brief IXPositionManager의 단위 테스트용 Mock 객체
 */
class MockPositionManager : public IXPositionManager {
private:
    ulong m_magic;
    int   m_pulseCount;
    bool  m_modifyResult;

public:
    MockPositionManager() : m_magic(0), m_pulseCount(0), m_modifyResult(true) {}
    virtual ~MockPositionManager() override {}

    //--- Mock Controls
    int  GetPulseCount() const { return m_pulseCount; }
    void ResetPulseCount() { m_pulseCount = 0; }
    void SetModifyResult(bool success) { m_modifyResult = success; }

    //--- IXPositionManager Interfaces
    virtual void SetMagic(ulong magic) override { m_magic = magic; }
    virtual void Pulse(ICXParam* xp) override {
        m_pulseCount++;
        PrintFormat("[MOCK-POSMGR] Pulse called. Count: %d", m_pulseCount);
    }
    virtual bool ModifyPosition(ICXParam* xp, ulong ticket, double sl, double tp) override {
        PrintFormat("[MOCK-POSMGR] ModifyPosition: Ticket:%I64u, SL:%.5f, TP:%.5f", ticket, sl, tp);
        return m_modifyResult;
    }
    virtual void ScanAndBind(ICXParam* xp, CObject* sessionMgr) override {
        Print("[MOCK-POSMGR] ScanAndBind called.");
    }
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") override {
        return "[MOCK-POSMGR] Audit Log";
    }
};

#endif
