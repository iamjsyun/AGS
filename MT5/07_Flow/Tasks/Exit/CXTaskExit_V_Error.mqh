#ifndef CX_TASK_EXIT_V_ERROR_MQH
#define CX_TASK_EXIT_V_ERROR_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXMessageProvider.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_V_Error
 * @brief [Verify] Retry scheduling and response upon liquidation failure
 */
class CXTaskExit_V_Error : public IXTask {
public:
    virtual string Name() override { return "Exit_V_Error"; }
    virtual string GetRequiredServices() override { return ""; }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // When the asset is not removed for a long time after liquidation request
        if(sig.GetXAExit() == XA_ACTIVE && sig.GetStatus() < XE_CLOSED_SIGNAL) {
            if(IsTimedOut()) {
                string err = "Liquidation Failed after persistent retries";
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("EXIT-V-ERR", xp, "FAILED: " + err));
                xp.SetString("[EXIT-V-ERR] " + err); 
                CXMessageProvider::UpdateStatus(sig, XE_ERROR, err);
                return SESSION_ERROR;
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
