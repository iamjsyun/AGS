#ifndef CX_TASK_ACTIVE_P_ALIGN_MQH
#define CX_TASK_ACTIVE_P_ALIGN_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\..\01_Core\Interfaces\IXPositionManager.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskActive_P_Align
 * @brief [Persistence] Synchronize terminal state with DB state
 * [v2.1 Smart PVB] Implement GetRequiredServices
 */
class CXTaskActive_P_Align : public IXTask {
private:
    IRepository*       m_repo;
    IXPositionManager* m_posMgr;

public:
    CXTaskActive_P_Align() : m_repo(NULL), m_posMgr(NULL) {}
    virtual string Name() override { return "Active_P_Align"; }
    
    virtual string GetRequiredServices() override { return "repo, pos_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo   = CX_GET_OBJ(ctx, "repo", IRepository);
        m_posMgr = CX_GET_OBJ(ctx, "pos_mgr", IXPositionManager);
        return (m_repo != NULL && m_posMgr != NULL) && IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        bool exists = (xp.GetInt() == 1);
        
        if(!exists && sig.GetStatus() < XE_CLOSED_SIGNAL) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("ACTIVE-P-ALIGN", xp, "Mismatch: Position not found. Triggering Align."));
            
            m_posMgr.Pulse(xp);
            if(m_repo.UpdateStatus(sig)) {
                XP_LOG_OK(xp, CXAuditFormatter::Build("ACTIVE-P-ALIGN", xp, "SUCCESS: DB Aligned."));
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
