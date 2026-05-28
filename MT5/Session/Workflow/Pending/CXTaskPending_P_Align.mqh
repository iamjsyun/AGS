#ifndef CX_TASK_PENDING_P_ALIGN_MQH
#define CX_TASK_PENDING_P_ALIGN_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXOrderManager.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskPending_P_Align
 * @brief [Persistence] 대기 주문 터미널 상태와 DB 상태 동기화
 */
class CXTaskPending_P_Align : public IXTask {
public:
    virtual string Name() override { return "Pending_P_Align"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        bool exists = (xp.GetInt() == 1);
        
        if(!exists && sig.GetStatus() == XE_PENDING_PLACED) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("PEND-P-ALIGN", xp, "Mismatch: Order not found. Triggering Pulse."));
            
            IXOrderManager* ordMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
            if(IS_VALID(ordMgr)) {
                ordMgr.Pulse(xp);
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
