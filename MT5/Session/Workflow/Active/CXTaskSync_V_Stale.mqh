#ifndef CX_TASK_SYNC_V_STALE_MQH
#define CX_TASK_SYNC_V_STALE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskSync_V_Stale
 * @brief [Verify] DB 내 오래된 PENDING 데이터 강제 정리
 */
class CXTaskSync_V_Stale : public IXTask {
public:
    virtual string Name() override { return "Sync_V_Stale"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        // XE_PENDING_REQ 상태로 5분 이상 방치된 데이터는 좀비로 간주
        if(sig.GetStatus() == XE_PENDING_REQ) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("SYNC-V-STALE", xp, "Monitoring PENDING_REQ timeout"));
            if(IsTimedOut()) { 
                XP_LOG_WARN(xp, CXAuditFormatter::Build("SYNC-V-STALE", xp, "ALERT: Stale PENDING_REQ. Rolling back."));
                sig.SetStatus(XE_READY);
                sig.SetStatusMsg("Stale Request Rolled Back");
                if(repo.UpdateStatus(sig)) {
                    XP_LOG_OK(xp, CXAuditFormatter::Build("SYNC-V-STALE", xp, "SUCCESS: Zombie cleaned."));
                }
                return TASK_BREAK; 
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
