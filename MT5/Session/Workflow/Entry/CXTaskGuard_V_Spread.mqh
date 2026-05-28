#ifndef CX_TASK_GUARD_V_SPREAD_MQH
#define CX_TASK_GUARD_V_SPREAD_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskGuard_V_Spread
 * @brief [Guard] 진입 직전 스프레드 급증 차단
 */
class CXTaskGuard_V_Spread : public IXTask {
public:
    virtual string Name() override { return "Guard_V_Spread"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        ICXSymbolManager* symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
        
        if(IS_INVALID(sig) || IS_INVALID(symMgr)) return TASK_BREAK;

        string symbol = sig.GetSymbol();
        int spread = symMgr.GetSpread(symbol);
        int maxSpread = 100; // 가변 설정값 필요

        // [Muted] XP_LOG_TRACE(xp, CXAuditFormatter::Build("GUARD-V-SPREAD", xp, StringFormat("Checking Spread: %d (Max:%d)", spread, maxSpread)));

        if(spread > maxSpread) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("GUARD-V-SPREAD", xp, StringFormat("YIELD: High Spread (%d > %d)", spread, maxSpread)));
            
            if(IsMaxRetriesExceeded()) {
                string err = StringFormat("Spread remained high (%d) after max retries.", spread);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("GUARD-V-SPREAD", xp, "FAILED: " + err));
                if(IS_VALID(xp)) xp.SetString("[GUARD-V-SPREAD] " + err);
                return SESSION_ERROR;
            }
            return TASK_YIELD;
        }

        ResetRetry();
        return TASK_CONTINUE;
    }
};

#endif
