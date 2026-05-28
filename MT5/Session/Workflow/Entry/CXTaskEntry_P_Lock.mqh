#ifndef CX_TASK_ENTRY_P_LOCK_MQH
#define CX_TASK_ENTRY_P_LOCK_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_P_Lock
 * @brief [Persistence] DB에 PENDING_REQ 상태 기록 (잠금)
 */
class CXTaskEntry_P_Lock : public IXTask {
public:
    virtual string Name() override { return "Entry_P_Lock"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        if(sig.GetStatus() >= XE_PENDING_REQ) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-P-LOCK", xp, "SKIP: Already Locked"));
            return TASK_CONTINUE;
        }

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-P-LOCK", xp, "Writing PENDING_REQ Lock to DB..."));
        CXMessageProvider::UpdateStatus(sig, XE_PENDING_REQ, "Intent: Entry Requesting...");
        
        if(repo.UpdateStatus(sig)) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("ENTRY-P-LOCK", xp, "SUCCESS: Status Locked."));
            return TASK_CONTINUE;
        }

        XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-P-LOCK", xp, "FAILED: DB Update Error."));
        return TASK_BREAK; 
    }
};

#endif
