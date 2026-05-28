#ifndef CX_TASK_EXIT_V_TERMINAL_MQH
#define CX_TASK_EXIT_V_TERMINAL_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskExit_V_Terminal
 * @brief [Verify] 터미널 내 실물 자산 소멸 확인 (L3 Verification)
 */
class CXTaskExit_V_Terminal : public IXTask {
public:
    virtual string Name() override { return "Exit_V_Terminal"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        
        if(IS_INVALID(sig) || IS_INVALID(invMgr)) return TASK_BREAK;

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket <= 0) {
            return TASK_CONTINUE; 
        }

        bool exists = invMgr.IsAssetExists(ticket, sig.GetType());

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
