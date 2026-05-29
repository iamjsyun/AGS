#ifndef CX_TASK_SYNC_V_STALE_MQH
#define CX_TASK_SYNC_V_STALE_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskSync_V_Stale
 * @brief [Verify] DB 내 오래된 PENDING 데이터 강제 정리
 */
class CXTaskSync_V_Stale : public IXTask {
private:
    IRepository* m_repo;

public:
    virtual string Name() override { return "Sync_V_Stale"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(m_repo)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // XE_PENDING_REQ 상태로 5분 이상 방치된 데이터는 좀비로 간주
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
