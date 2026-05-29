#ifndef CX_TASK_EXIT_P_FINALIZE_MQH
#define CX_TASK_EXIT_P_FINALIZE_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Core\Logger\CXMessageProvider.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_P_Finalize
 * @brief [Persistence] DB 상태 최종 확정 (CLOSED)
 */
class CXTaskExit_P_Finalize : public IXTask {
public:
    virtual string Name() override { return "Exit_P_Finalize"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        int finalStatus = sig.GetStatus();
        if(finalStatus < XE_CLOSED_SIGNAL) finalStatus = XE_CLOSED_SIGNAL;

        // [v14.6 Manual-Close Fast-Track / General Exit completion]
        sig.SetXAExit(XA_CLOSED_COMPLETED); // 2
        XP_LOG_INFO(xp, CXAuditFormatter::Build("EXIT-P-FIN", xp, StringFormat("Exit Finalized: xa_exit=2, status=%d", finalStatus)));

        CXMessageProvider::UpdateStatus(sig, finalStatus, "Liquidation Finalized. Session Closed.");
        if(repo.UpdateStatus(sig)) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("EXIT-P-FIN", xp, StringFormat("SUCCESS: Finalized as %d", finalStatus)));
            return SESSION_CLOSED;
        }

        return TASK_YIELD; 
    }
};

#endif
