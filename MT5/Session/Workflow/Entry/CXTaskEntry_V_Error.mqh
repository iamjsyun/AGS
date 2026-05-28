#ifndef CX_TASK_ENTRY_V_ERROR_MQH
#define CX_TASK_ENTRY_V_ERROR_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_V_Error
 * @brief [Verify] 브로커 진입 리젝션(Rejection) 대응 및 로깅
 */
class CXTaskEntry_V_Error : public IXTask {
public:
    virtual string Name() override { return "Entry_V_Error"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // 티켓이 없고 상태가 PENDING_REQ 이상인데 타임아웃이면 에러 처리
        if(sig.GetTicket() <= 0 && sig.GetStatus() == XE_PENDING_REQ) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-V-ERR", xp, "Monitoring Broker Rejection..."));
            if(IsTimedOut()) {
                string err = "Broker Request Rejected (Timeout)";
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-V-ERR", xp, "FAILED: " + err));
                xp.SetString("[ENTRY-V-ERR] " + err); 
                CXMessageProvider::UpdateStatus(sig, XE_ERROR, err);
                return SESSION_ERROR;
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
