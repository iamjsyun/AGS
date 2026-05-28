#ifndef CX_TASK_ACTIVE_P_ALIGN_MQH
#define CX_TASK_ACTIVE_P_ALIGN_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXPositionManager.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskActive_P_Align
 * @brief [Persistence] 터미널 상태와 DB 상태 동기화
 */
class CXTaskActive_P_Align : public IXTask {
public:
    virtual string Name() override { return "Active_P_Align"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        bool exists = (xp.GetInt() == 1);
        
        if(!exists && sig.GetStatus() < XE_CLOSED_SIGNAL) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("ACTIVE-P-ALIGN", xp, "Mismatch: Position not found. Triggering Align."));
            
            IXPositionManager* posMgr = CX_GET_OBJ(ctx, "pos_mgr", IXPositionManager);
            if(IS_VALID(posMgr)) {
                posMgr.Pulse(xp);
            }
            if(repo.UpdateStatus(sig)) {
                XP_LOG_OK(xp, CXAuditFormatter::Build("ACTIVE-P-ALIGN", xp, "SUCCESS: DB Aligned."));
            }
        } else {
            // [v14.16 Muted] XP_LOG_TRACE(xp, CXAuditFormatter::Build("ACTIVE-P-ALIGN", xp, "OK: Terminal and DB in sync."));
        }

        return TASK_CONTINUE;
    }
};

#endif
