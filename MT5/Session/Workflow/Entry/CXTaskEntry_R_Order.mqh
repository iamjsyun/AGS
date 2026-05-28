#ifndef CX_TASK_ENTRY_R_ORDER_MQH
#define CX_TASK_ENTRY_R_ORDER_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXOrderManager.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_R_Order
 * @brief [Request] 브로커에 주문 송신
 */
class CXTaskEntry_R_Order : public IXTask {
public:
    virtual string Name() override { return "Entry_R_Order"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        IXOrderManager* orderMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
        if(IS_INVALID(orderMgr)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-R-ORDER", xp, "FAILED: OrderManager context missing."));
            return TASK_BREAK;
        }

        ICXSignal* sig = xp.GetSignal();
        if(IS_VALID(sig) && (sig.GetTicket() > 0 || sig.GetStatus() >= XE_IN_TRANSIT)) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-R-ORDER", xp, "SKIP: Asset already in transit"));
            return TASK_CONTINUE;
        }

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-R-ORDER", xp, "Sending Physical Order to Broker..."));
        if(orderMgr.ExecuteEntry(xp)) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("ENTRY-R-ORDER", xp, "SUCCESS: Order Request Sent."));
            return TASK_CONTINUE;
        }

        string lastErr = xp.GetString();
        
        // [v14.48 Resilience] If waiting for market open, break task to stay in state 0 and retry.
        if(lastErr == "WAIT_MARKET_OPEN") {
            xp.SetString(""); // Clear signal
            return TASK_BREAK; 
        }

        if(lastErr == "") lastErr = "Broker Order Request Rejected";
        string finalErr = "FAILED: " + lastErr;
        XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-R-ORDER", xp, finalErr));
        xp.SetString("[ENTRY-R-ORDER] " + finalErr);
        return SESSION_ERROR;
    }
};

#endif
