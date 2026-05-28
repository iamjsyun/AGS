#ifndef CX_TASK_COMM_V_STATUS_MQH
#define CX_TASK_COMM_V_STATUS_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXLogger.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskComm_V_Status
 * @brief [Verify] 외부 통신 레이어(RemoteLogger) 연결 상태 확인
 */
class CXTaskComm_V_Status : public IXTask {
public:
    virtual string Name() override { return "Comm_V_Status"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXLogger* logger = CX_GET_OBJ(ctx, "logger", ICXLogger);
        
        XP_LOG_TRACE(xp, CXAuditFormatter::Build("COMM-V-STATUS", xp, "Verifying Infrastructure..."));

        if(IS_INVALID(logger)) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("COMM-V-STATUS", xp, "Global Logger unavailable. Silent mode."));
        } else {
            // [v14.17 Muted] XP_LOG_DEBUG(xp, CXAuditFormatter::Build("COMM-V-STATUS", xp, "OK: Logger connected."));
        }

        return TASK_CONTINUE;
    }
};

#endif
