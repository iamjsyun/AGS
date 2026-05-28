#ifndef CX_TASK_ACTIVE_L_STATUS_MQH
#define CX_TASK_ACTIVE_L_STATUS_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskActive_L_Status
 * @brief [Logic] 현재 상태에 따른 시퀀스 전이 판단
 */
class CXTaskActive_L_Status : public IXTask {
public:
    virtual string Name() override { return "Active_L_Status"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("ACTIVE-L-STATUS", xp, "Monitoring State"));

        if(sig.GetStatus() >= XE_CLOSED_SIGNAL) {
            XP_LOG_INFO(xp, CXAuditFormatter::Build("ACTIVE-L-STATUS", xp, "Terminal state detected. Redirecting to LIQUIDATING."));
            return SESSION_LIQUIDATING;
        }

        return TASK_CONTINUE;
    }
};

#endif
