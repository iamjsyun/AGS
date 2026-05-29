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
private:
    IRepository* m_repo;

public:
    virtual string Name() override { return "Exit_P_Lock"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(m_repo)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        if(sig.GetStatus() >= XE_PENDING_REQ) return TASK_CONTINUE;

        CXMessageProvider::UpdateStatus(sig, sig.GetStatus(), "Intent: Liquidation Requesting...");
        if(m_repo.UpdateStatus(sig)) {
            return TASK_CONTINUE;
        }

        return TASK_YIELD; 
    }
};

#endif
