#ifndef CX_TASK_EXIT_P_FINALIZE_MQH
#define CX_TASK_EXIT_P_FINALIZE_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\..\01_Core\Logger\CXMessageProvider.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_P_Finalize
 * @brief [Persistence] Finalize DB status (CLOSED)
 */
class CXTaskExit_P_Finalize : public IXTask {
private:
    IRepository* m_repo;

public:
    virtual string Name() override { return "Exit_P_Finalize"; }
    virtual string GetRequiredServices() override { return "repo"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(m_repo)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        int finalStatus = sig.GetStatus();
        if(finalStatus < XE_CLOSED_SIGNAL) finalStatus = XE_CLOSED_SIGNAL;

        // [v14.6 Manual-Close Fast-Track / General Exit completion]
        sig.SetXAExit(XA_CLOSED_COMPLETED); // 2
        XP_LOG_INFO(xp, CXAuditFormatter::Build("EXIT-P-FIN", xp, StringFormat("Exit Finalized: xa_exit=2, status=%d", finalStatus)));

        CXMessageProvider::UpdateStatus(sig, finalStatus, "Liquidation Finalized. Session Closed.");
        if(m_repo.UpdateStatus(sig)) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("EXIT-P-FIN", xp, StringFormat("SUCCESS: Finalized as %d", finalStatus)));
            return SESSION_CLOSED;
        }

        return TASK_YIELD; 
    }
};

#endif
