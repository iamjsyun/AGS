#ifndef CX_TASK_ACTIVE_R_ALPHA_APPLY_MQH
#define CX_TASK_ACTIVE_R_ALPHA_APPLY_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXPositionManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXGuard.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXPriceManager.mqh"

/**
 * @class CXTaskActive_R_AlphaApply
 * @brief 계산된 SL/TP를 브로커에 적용 (Action)
 */
class CXTaskActive_R_AlphaApply : public IXTask {
public:
    virtual string Name() override { return "Task_AlphaApply"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        //--- [v14.34 Fix] Error-State Liquidation Bypass
        if(sig.GetXAExit() == XA_ACTIVE) {
            XP_LOG_INFO(xp, CXAuditFormatter::Build("ALPHA-APPLY", xp, "Exit intent detected. Redirecting to LIQUIDATING."));
            return SESSION_LIQUIDATING;
        }

        if(sig.GetStatus() == XE_ERROR) return TASK_BREAK;

        double newSL = xp.GetDouble();
        if(newSL <= 0) return TASK_CONTINUE;

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("ALPHA-APPLY", xp, StringFormat("Attempting SL/Price Update: %.5f", newSL)));

        IXPositionManager* posMgr = CX_GET_OBJ(ctx, "pos_mgr", IXPositionManager);
        IXOrderManager* orderMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
        IXGuard* guard = CX_GET_OBJ(ctx, "guard", IXGuard);
        
        ulong ticket = (ulong)sig.GetTicket();
        ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        double currentPrice = IS_VALID(priceMgr) ? priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir()) : SymbolInfoDouble(sig.GetSymbol(), (sig.GetDir() == CX_DIR_BUY) ? SYMBOL_BID : SYMBOL_ASK);
        
        if(IS_VALID(guard) && !guard.ValidateStopLevel(sig.GetSymbol(), currentPrice, newSL)) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("ALPHA-APPLY", xp, StringFormat("StopLevel Violation. Target:%.5f", newSL)));
            return TASK_BREAK;
        }

        bool success = false;
        // [v14.42] Determine if we should modify Position or Order
        if(sig.GetStatus() >= XE_EXECUTED) {
            if(IS_VALID(posMgr)) success = posMgr.ModifyPosition(xp, ticket, newSL, sig.GetTP());
        } else {
            // It's still an order (TE/Pending stage)
            if(IS_VALID(orderMgr)) success = orderMgr.ModifyOrder(xp, ticket, newSL, sig.GetSL(), sig.GetTP());
        }

        if(success) {
            if(sig.GetStatus() >= XE_EXECUTED) sig.SetSL(newSL);
            else sig.UpdatePriceSignal(newSL);
            
            XP_LOG_OK(xp, CXAuditFormatter::Build("ALPHA-APPLY", xp, "SUCCESS: Asset Modified."));
        } else {
            string lastErr = xp.GetString();
            if(lastErr == "") lastErr = "Broker Rejected";
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ALPHA-APPLY", xp, "FAILED: " + lastErr));
        }

        return TASK_CONTINUE;
    }
};

#endif
