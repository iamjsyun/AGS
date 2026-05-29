#ifndef CX_TASK_EXIT_R_ORDER_MQH
#define CX_TASK_EXIT_R_ORDER_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Interfaces\IXExitManager.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\Core\Interfaces\ICXAssetManager.mqh"

/**
 * @class CXTaskExit_R_Order
 * @brief [Request] 브로커에 청산(Close/Cancel) 주문 송신
 */
class CXTaskExit_R_Order : public IXTask {
private:
    IXExitManager*   m_exitMgr;
    ICXAssetManager* m_invMgr;

public:
    CXTaskExit_R_Order() {
        // [v1.0 Scenario F] 30s Retry Timeout for Broker Disconnect Recovery
        SetTimeout(30); 
    }

    virtual string Name() override { return "Exit_R_Order"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_exitMgr = CX_GET_OBJ(ctx, "exit_mgr", IXExitManager);
        m_invMgr  = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(m_exitMgr) || IS_INVALID(m_invMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // [v14.4 Idempotency Guard] 이미 요청이 나갔다면 중복 송신 차단
        if(xp.GetInt() == 3) {
            return TASK_CONTINUE;
        }

        // [v1.0 Scenario H] Pre-Close Shadowing Sync
        // Double check terminal reality before sending liquidation request
        m_invMgr.SyncToSignal(sig);

        // [v14.4 Physical Asset Guard] 티켓이 이미 없다면 송신할 필요 없음
        ulong ticket = (ulong)sig.GetTicket();
        if(ticket > 0 && !m_invMgr.IsAssetExists(ticket, sig.GetType())) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, StringFormat("Physical Asset(%I64u) already gone. Skipping.", ticket)));
            return TASK_CONTINUE; 
        }
        
        // [v1.0 Scenario E & F] Massive SID Sweep with Retry Loop
        if(m_exitMgr.SweepBySid(xp, sig.GetSid())) {
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
