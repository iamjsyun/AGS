#ifndef MOCK_REPOSITORY_MQH
#define MOCK_REPOSITORY_MQH

#include "..\..\Core\Interfaces\IRepository.mqh"

/**
 * @class MockRepository
 * @brief IRepository의 단위 테스트용 Mock 객체
 */
class MockRepository : public IRepository {
private:
    ICXSignal* m_mockSignal;

public:
    MockRepository() : m_mockSignal(NULL) {}
    virtual ~MockRepository() override { SAFE_DELETE(m_mockSignal); }
    
    void SetMockSignal(ICXSignal* sig) { 
        SAFE_DELETE(m_mockSignal); 
        m_mockSignal = sig; 
    }

    virtual void SaveSignal(ICXSignal* signal) override {}
    virtual void LoadParam(ICXParam* param) override {}
    virtual int  GetStatusBySid(const string sid) override { return 0; }
    virtual bool UpdateStatus(ICXSignal* signal) override { return true; }
    virtual bool ForceUpdateIntent(ICXSignal* signal) override { return true; }
    virtual int  LoadActiveSignals(CArrayObj* list) override { return 0; }
    virtual int  LoadEntrySignals(CArrayObj* list) override { return 0; }
    virtual int  LoadExitSignals(CArrayObj* list) override { return 0; }
    
    virtual ICXSignal* GetSignalBySid(const string sid) override { 
        if(m_mockSignal != NULL && m_mockSignal.GetSid() == sid) {
            // Return a copy to mimic DB behavior
            CXSignal* copy = new CXSignal();
            // In a real mock we'd copy fields, but for simple test we just return the pointer (risky) or implement Copy()
            // Let's just return the pointer but ensure the caller knows it might be shared in this simple mock.
            // Actually, CXTaskIntentWatch deletes the result: 'delete fresh;'
            // So we MUST return a new object.
            
            copy.SetSid(m_mockSignal.GetSid());
            copy.SetXAExit(m_mockSignal.GetXAExit());
            return copy;
        }
        return NULL; 
    }
    virtual bool DeleteBySid(const string sid) override { return true; }
    virtual ICXSignal* GetSignalByCnoSno(int cno, int sno, string symbol) override { return NULL; }
};

#endif
