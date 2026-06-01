#ifndef CX_TASK_SYNC_V_STALE_MQH
#define CX_TASK_SYNC_V_STALE_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskSync_V_Stale
 * @brief [Verify] Force cleanup of stale PENDING data in DB
 */
class CXTaskSync_V_Stale : public IXTask {
private:
    IRepository* m_repo;

public:
    virtual string Name() override { return "Sync_V_Stale"; }
    virtual string GetRequiredServices() override { return "repo"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(m_repo)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // Data left in XE_PENDING_REQ state for more than 5 minutes is considered a zombie
        if(sig.GetStatus() == XE_PENDING_REQ) {
            if(IsTimedOut()) { 
                XP_LOG_WARN(xp, CXAuditFormatter::Build("SYNC-V-STALE", xp, "ALERT: Stale PENDING_REQ. Rolling back."));
                sig.SetStatus(XE_READY);
                sig.SetStatusMsg("Stale Request Rolled Back");
                if(m_repo.UpdateStatus(sig)) {
                    XP_LOG_OK(xp, CXAuditFormatter::Build("SYNC-V-STALE", xp, "SUCCESS: Zombie cleaned."));
                }
                return TASK_BREAK; 
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
