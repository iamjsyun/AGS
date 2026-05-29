#ifndef CX_TASK_EXIT_L_PREPARE_MQH
#define CX_TASK_EXIT_L_PREPARE_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"

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
