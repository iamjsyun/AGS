#ifndef CX_TASK_EXIT_V_TERMINAL_MQH
#define CX_TASK_EXIT_V_TERMINAL_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_V_Terminal
 * @brief [Verify] Verify deletion of physical asset in terminal (L3 Verification)
 */
class CXTaskExit_V_Terminal : public IXTask {
private:
    ICXAssetManager* m_invMgr;

public:
    virtual string Name() override { return "Exit_V_Terminal"; }
    virtual string GetRequiredServices() override { return "asset_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(m_invMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket <= 0) {
            return TASK_CONTINUE; 
        }

        bool exists = m_invMgr.IsAssetExists(ticket, sig.GetType());

        if(exists) {
            IncrementRetry();
            if(GetRetryCount() > 5) {
                string assetErr = StringFormat("Physical Asset(%I64u) still exists after max retries.", ticket);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("EXIT-V-TERM", xp, "FAILED: " + assetErr));
                if(IS_VALID(xp)) xp.SetString("[EXIT-V-TERM] " + assetErr);
                return SESSION_ERROR;
            }
            return TASK_YIELD;
        }

        XP_LOG_OK(xp, CXAuditFormatter::Build("EXIT-V-TERM", xp, StringFormat("SUCCESS: Ticket(%I64u) Absence Verified.", ticket)));
        return TASK_CONTINUE;
    }
};

#endif
