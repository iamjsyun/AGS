#ifndef CX_TASK_EXIT_P_LOCK_MQH
#define CX_TASK_EXIT_P_LOCK_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Core\Logger\CXMessageProvider.mqh"

/**
 * @class CXTaskExit_P_Lock
 * @brief [Persistence] DB에 청산 진행 중 상태 기록 (잠금)
 */
class CXTaskExit_P_Lock : public IXTask {
public:
    virtual string Name() override { return "Exit_P_Lock"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        if(sig.GetStatus() >= XE_PENDING_REQ) return TASK_CONTINUE;

        CXMessageProvider::UpdateStatus(sig, sig.GetStatus(), "Intent: Liquidation Requesting...");
        if(repo.UpdateStatus(sig)) {
            return TASK_CONTINUE;
        }

        return TASK_YIELD; 
    }
};

#endif
