#ifndef CX_TASK_ACTIVE_P_CLOSED_MQH
#define CX_TASK_ACTIVE_P_CLOSED_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskActive_P_Closed
 * @brief [Persistence] 세션의 최종 종료 및 뒷정리 (v17.6)
 */
class CXTaskActive_P_Closed : public IXTask {
public:
    virtual string Name() override { return "Task_Closed"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        // 최종 상태 보존 (xa_exit=2 마킹)
        if(sig.GetXAExit() < XA_CLOSED_COMPLETED) {
            sig.SetXAExit(XA_CLOSED_COMPLETED);
            repo.UpdateStatus(sig);
            XP_LOG_OK(xp, CXAuditFormatter::Build("TASK-CLOSED", xp, "Session Finalized. Mark as Completed."));
        }

        return TASK_CONTINUE;
    }
};

#endif
