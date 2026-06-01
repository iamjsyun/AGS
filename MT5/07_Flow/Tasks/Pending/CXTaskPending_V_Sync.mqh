#ifndef CX_TASK_PENDING_V_SYNC_MQH
#define CX_TASK_PENDING_V_SYNC_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskPending_V_Sync
 * @brief Synchronize terminal physical state and monitor intent commands
 * [v2.1 Smart PVB] Implementation of GetRequiredServices
 */
class CXTaskPending_V_Sync : public IXTask {
private:
    ICXAssetManager* m_assetMgr;
    IRepository*     m_repo;

public:
    virtual string Name() override { return "Pending_V_Sync"; }
    
    virtual string GetRequiredServices() override { return "asset_mgr, repo"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(m_repo) || IS_INVALID(m_assetMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        if(sig.GetXAExit() == XA_ACTIVE) {
            XP_LOG_INFO(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, "Exit command detected. Moving to LIQUIDATING."));
            return SESSION_LIQUIDATING;
        }

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket > 0 && m_assetMgr.IsPositionExists(ticket)) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, StringFormat("Order filled! Ticket:%I64u is now a Position.", ticket)));
            CXMessageProvider::UpdateStatus(sig, XE_EXECUTED, "Pending Order Filled");
            m_repo.UpdateStatus(sig);
            return SESSION_ACTIVE;
        }

        if(sig.GetStatus() == XE_ERROR) return SESSION_ERROR;
        if(sig.GetStatus() >= XE_EXECUTED) return SESSION_ACTIVE;
        if(sig.GetTicket() <= 0) return TASK_BREAK;

        return TASK_CONTINUE;
    }
};

#endif
