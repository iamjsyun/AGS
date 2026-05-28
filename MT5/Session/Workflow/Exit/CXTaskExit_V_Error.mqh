#ifndef CX_TASK_EXIT_V_ERROR_MQH
#define CX_TASK_EXIT_V_ERROR_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_V_Error
 * @brief [Verify] 청산 실패 시 재시도 스케줄링 및 대응
 */
class CXTaskExit_V_Error : public IXTask {
public:
    virtual string Name() override { return "Exit_V_Error"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // 청산 요청 후 장시간 소멸되지 않을 경우
        if(sig.GetXAExit() == XA_ACTIVE && sig.GetStatus() < XE_CLOSED_SIGNAL) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("EXIT-V-ERR", xp, "Monitoring Liquidation Completion..."));
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
