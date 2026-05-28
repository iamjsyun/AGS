#ifndef CX_TASK_EXIT_L_PREPARE_MQH
#define CX_TASK_EXIT_L_PREPARE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_L_Prepare
 * @brief [Logic] 청산 조건 검증 및 준비 (I/O 없음)
 */
class CXTaskExit_L_Prepare : public IXTask {
public:
    virtual string Name() override { return "Exit_L_Prepare"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("EXIT-L-PREP", xp, "Checking Liquidation Intent"));

        if(sig.GetStatus() >= XE_CLOSED_SIGNAL) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("EXIT-L-PREP", xp, "Already Closed. Redirecting to CLOSED."));
            return SESSION_CLOSED;
        }

        if(sig.GetXAExit() != XA_ACTIVE) {
            // [v14.19 Muted] XP_LOG_DEBUG(xp, CXAuditFormatter::Build("EXIT-L-PREP", xp, "Yield: Waiting for Exit Intent."));
            return TASK_CONTINUE; 
        }

        XP_LOG_INFO(xp, CXAuditFormatter::Build("EXIT-L-PREP", xp, "Liquidation Intent Confirmed."));
        return TASK_CONTINUE;
    }
};

#endif
