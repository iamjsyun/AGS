#ifndef CX_TASK_EXIT_L_PREPARE_MQH
#define CX_TASK_EXIT_L_PREPARE_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_L_Prepare
 * @brief [Logic] Liquidation condition verification and preparation (No I/O)
 */
class CXTaskExit_L_Prepare : public IXTask {
public:
    virtual string Name() override { return "Exit_L_Prepare"; }
    virtual string GetRequiredServices() override { return ""; }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        if(sig.GetStatus() >= XE_CLOSED_SIGNAL) {
            return SESSION_CLOSED;
        }

        if(sig.GetXAExit() != XA_ACTIVE) {
            return TASK_CONTINUE; 
        }

        XP_LOG_INFO(xp, CXAuditFormatter::Build("EXIT-L-PREP", xp, "Liquidation Intent Confirmed."));
        return TASK_CONTINUE;
    }
};

#endif
