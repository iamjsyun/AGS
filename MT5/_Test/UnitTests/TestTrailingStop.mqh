#ifndef TEST_TRAILING_STOP_MQH
#define TEST_TRAILING_STOP_MQH

#include "..\..\Workflow\Tasks\Trailing\CXTaskTrail_V_Activate.mqh"
#include "..\..\Workflow\Tasks\Trailing\CXTaskTrail_V_Extremum.mqh"
#include "..\..\Workflow\Tasks\Trailing\CXTaskTrail_L_Evaluate.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\Mocks\MockPriceManager.mqh"
#include "..\Mocks\MockTerminalPlatform.mqh"
#include "..\Scenarios\CXVirtualPricer.mqh"

#include "..\..\Workflow\Tasks\Trailing\CXTaskTrail_R_Execute.mqh"
#include "..\Mocks\MockOrderManager.mqh"
#include "..\Mocks\MockSymbolManager.mqh"

class TestTrailingStop {
public:
    static bool Run() {
        Print("--- Running TestTrailingStop ---");
        bool allPassed = true;
        
        CXContext ctx;
        CXVirtualPricer pricer("GOLD#", 0.01);
        pricer.InitModel("Linear", 2350.00, 0);
        MockPriceManager priceMgr(NULL);
        priceMgr.SetPricer(GetPointer(pricer));
        MockTerminalPlatform terminal;
        MockOrderManager orderMgr;
        MockSymbolManager symMgr;
        
        ctx.Register("price_mgr", GetPointer(priceMgr));
        ctx.Register("terminal_platform", GetPointer(terminal));
        ctx.Register("order_mgr", GetPointer(orderMgr));
        ctx.Register("sym_mgr", GetPointer(symMgr));
        
        CXParam xp;
        CXSignal sig;
        sig.SetSymbol("GOLD#");
        sig.SetDir(CX_DIR_BUY);
        sig.SetType(ORDER_TYPE_BUY);
        sig.SetPriceOpen(2350.00);
        sig.SetTSStart(2000); // TS Start at +2000pt ($20.00)
        sig.SetTSStep(500);   // TS Step 500pt ($5.00)
        sig.SetTicket(90001);
        sig.SetSid("TEST-TS-01");
        xp.SetSignal(GetPointer(sig));
        
        CXTaskTrail_V_Activate taskAct(TRAIL_MODE_EXIT);
        CXTaskTrail_V_Extremum taskExt(TRAIL_MODE_EXIT);
        CXTaskTrail_L_Evaluate taskEval(TRAIL_MODE_EXIT);
        CXTaskTrail_R_Execute  taskExec(TRAIL_MODE_EXIT);
        
        if(!taskAct.Bind(GetPointer(ctx)) ||
           !taskExt.Bind(GetPointer(ctx)) ||
           !taskEval.Bind(GetPointer(ctx)) ||
           !taskExec.Bind(GetPointer(ctx))) {
            Print("  [FAIL] Failed to bind context to trailing stop tasks.");
            return false;
        }

        // 1. Below trigger activation test
        // ... (existing tests) ...
        pricer.OverridePrice(2360.00);
        int result = taskAct.Execute(GetPointer(xp), GetPointer(ctx));
        ICXParam* pActive = ctx.GetParam("TS_Active_TEST-TS-01");
        if(result == TASK_CONTINUE && (IS_INVALID(pActive) || pActive.GetInt() != 1)) {
            Print("  [PASS] TS not activated below trigger profit.");
        } else {
            allPassed = false;
        }
        
        // 2. Above trigger activation test
        pricer.OverridePrice(2375.00);
        result = taskAct.Execute(GetPointer(xp), GetPointer(ctx));
        pActive = ctx.GetParam("TS_Active_TEST-TS-01");
        if(result == SESSION_TRAILING_STOP && IS_VALID(pActive) && pActive.GetInt() == 1) {
            Print("  [PASS] TS activated above trigger profit.");
        } else {
            allPassed = false;
        }
        
        // 3. Peak/Extremum price tracking test
        taskExt.Execute(GetPointer(xp), GetPointer(ctx));
        ICXParam* pExt = ctx.GetParam("TS_Extreme_TEST-TS-01");
        if(IS_VALID(pExt) && MathAbs(pExt.GetDouble() - 2375.00) < 0.01) {
            Print("  [PASS] Initial extremum set to 2375.00.");
        } else {
            allPassed = false;
        }
        
        pricer.OverridePrice(2380.00);
        taskExt.Execute(GetPointer(xp), GetPointer(ctx));
        pExt = ctx.GetParam("TS_Extreme_TEST-TS-01");
        if(IS_VALID(pExt) && MathAbs(pExt.GetDouble() - 2380.00) < 0.01) {
            Print("  [PASS] Extremum updated to higher peak 2380.00.");
        } else {
            allPassed = false;
        }
        
        // 4. Retracement / Rebound evaluate test
        pricer.OverridePrice(2378.00);
        xp.SetInt(0);
        taskEval.Execute(GetPointer(xp), GetPointer(ctx));
        if(xp.GetInt() != 20) {
            Print("  [PASS] TS evaluate did not trigger below step retracement.");
        } else {
            allPassed = false;
        }
        
        pricer.OverridePrice(2374.00);
        taskEval.Execute(GetPointer(xp), GetPointer(ctx));
        if(xp.GetInt() == 20) {
            Print("  [PASS] Retracement >= step triggered liquidation code 20.");
        } else {
            allPassed = false;
        }

        // 5. Request Execution Test (Logging Only)
        int resExec = taskExec.Execute(GetPointer(xp), GetPointer(ctx));
        if(resExec == TASK_CONTINUE) {
            Print("  [PASS] TS Retraction execution (logging) success.");
        } else {
            PrintFormat("  [FAIL] TS Retraction execution unexpected result: %d", resExec);
            allPassed = false;
        }

        return allPassed;
    }
};

#endif