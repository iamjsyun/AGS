//+------------------------------------------------------------------+
//|                                             MockExitManager.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Mock Exit Manager for task-level unit testing             |
//+------------------------------------------------------------------+
#ifndef MOCK_EXIT_MANAGER_MQH
#define MOCK_EXIT_MANAGER_MQH

#include "..\..\Core\Interfaces\IXExitManager.mqh"
#include "MockTerminalPlatform.mqh"

/**
 * @class MockExitManager
 * @brief IXExitManager의 단위 테스트용 Mock 객체
 */
class MockExitManager : public IXExitManager {
private:
    ulong                 m_magic;
    bool                  m_sweepResult;
    bool                  m_absenceResult;
    MockTerminalPlatform* m_terminal;

public:
    MockExitManager(MockTerminalPlatform* terminal) 
        : m_magic(0), m_sweepResult(true), m_absenceResult(true), m_terminal(terminal) {}
    virtual ~MockExitManager() override {}

    //--- Mock Controls
    void SetSweepResult(bool success) { m_sweepResult = success; }
    void SetAbsenceResult(bool absence) { m_absenceResult = absence; }

    //--- IXExitManager Interfaces
    virtual void SetMagic(ulong magic) override { m_magic = magic; }
    virtual bool ExecuteExit(ICXParam* xp) override { return true; }
    virtual bool CloseByTicket(ICXParam* xp, ICXSignal* sig) override { return true; }
    
    virtual bool SweepBySid(ICXParam* xp, string sid) override {
        PrintFormat("[MOCK-EXITMGR] SweepBySid: SID:%s", sid);
        if(!m_sweepResult) return false;
        
        if(IS_VALID(m_terminal)) {
            return m_terminal.SweepBySid(xp, m_magic, sid);
        }
        return true;
    }
    
    virtual bool SweepByMagic(ICXParam* xp, ulong magic) override {
        PrintFormat("[MOCK-EXITMGR] SweepByMagic: Magic:%I64u", magic);
        if(IS_VALID(m_terminal)) {
            return m_terminal.SweepByMagic(xp, magic);
        }
        return true;
    }
    
    virtual bool VerifyPhysicalAbsence(string sid) override {
        PrintFormat("[MOCK-EXITMGR] VerifyPhysicalAbsence: SID:%s", sid);
        if(!m_absenceResult) return false;
        
        if(IS_VALID(m_terminal)) {
            return m_terminal.VerifyPhysicalAbsence(m_magic, sid);
        }
        return true;
    }
};

#endif
