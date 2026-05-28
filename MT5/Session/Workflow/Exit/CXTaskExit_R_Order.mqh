#ifndef CX_TASK_EXIT_R_ORDER_MQH
#define CX_TASK_EXIT_R_ORDER_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXExitManager.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"

/**
 * @class CXTaskExit_R_Order
 * @brief [Request] 브로커에 청산(Close/Cancel) 주문 송신
 */
class CXTaskExit_R_Order : public IXTask {
public:
    CXTaskExit_R_Order() {
        // [v1.0 Scenario F] 30s Retry Timeout for Broker Disconnect Recovery
        SetTimeout(30); 
    }

    virtual string Name() override { return "Exit_R_Order"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        IXExitManager* exitMgr = CX_GET_OBJ(ctx, "exit_mgr", IXExitManager);
        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        
        if(IS_INVALID(exitMgr) || IS_INVALID(invMgr)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, "FAILED: Required context missing."));
            return TASK_BREAK;
        }

        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // [v14.4 Idempotency Guard] 이미 요청이 나갔다면 중복 송신 차단
        if(xp.GetInt() == 3) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, "SKIP: Liquidation already requested."));
            return TASK_CONTINUE;
        }

        // [v1.0 Scenario H] Pre-Close Shadowing Sync
        // Double check terminal reality before sending liquidation request
        if(IS_VALID(invMgr)) {
            invMgr.SyncToSignal(sig);
        }

        // [v14.4 Physical Asset Guard] 티켓이 이미 없다면 송신할 필요 없음
        ulong ticket = (ulong)sig.GetTicket();
        if(ticket > 0 && !invMgr.IsAssetExists(ticket, sig.GetType())) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, StringFormat("Physical Asset(%I64u) already gone. Skipping.", ticket)));
            return TASK_CONTINUE; 
        }

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, StringFormat("Sending Liquidation Order for Ticket:%I64u...", ticket)));
        
        // [v1.0 Scenario E & F] Massive SID Sweep with Retry Loop
        if(exitMgr.SweepBySid(xp, sig.GetSid())) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, "SUCCESS: Massive SID Sweep executed."));
            xp.SetInt(3); // Mark as requested
            return TASK_CONTINUE;
        }

        // [v1.0 Scenario F] Broker Offline / Reconnect Retry (TASK_YIELD)
        string lastErr = xp.GetString();
        if(lastErr == "") lastErr = "Broker Liquidation Request Rejected";
        
        XP_LOG_WARN(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, StringFormat("RETRY: %s. Retrying via TASK_YIELD...", lastErr)));
        return TASK_YIELD; 
    }
};

#endif
