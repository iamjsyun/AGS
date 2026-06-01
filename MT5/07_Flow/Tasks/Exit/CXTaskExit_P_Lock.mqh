#ifndef CX_TASK_EXIT_P_LOCK_MQH
#define CX_TASK_EXIT_P_LOCK_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\..\01_Core\Logger\CXMessageProvider.mqh"

/**
 * @class CXTaskExit_P_Lock
 * @brief [Persistence] Record liquidation in progress status in DB (Lock)
 */
class CXTaskExit_P_Lock : public IXTask {
private:
    IRepository* m_repo;

public:
    virtual string Name() override { return "Exit_P_Lock"; }
    virtual string GetRequiredServices() override { return "repo"; }

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
