#ifndef TEST_TRAILING_ENTRY_MQH
#define TEST_TRAILING_ENTRY_MQH

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

class TestTrailingEntry {
public:
    static bool Run() {
        Print("--- Running TestTrailingEntry ---");
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
        // ... (existing signal setup) ...
        sig.SetSymbol("GOLD#");
        sig.SetDir(CX_DIR_BUY);
        sig.SetType(ORDER_LIMIT);
        sig.SetPriceOpen(2350.00);
        sig.SetPriceSignal(2350.00);
        sig.SetTEStart(300);
        sig.SetTEStep(100);
        sig.SetTELimit(500);
        sig.SetSid("TEST-TE-01");
        xp.SetSignal(GetPointer(sig));
        
        CXTaskTrail_V_Activate taskAct(TRAIL_MODE_ENTRY);
        CXTaskTrail_V_Extremum taskExt(TRAIL_MODE_ENTRY);
        CXTaskTrail_L_Evaluate taskEval(TRAIL_MODE_ENTRY);
        CXTaskTrail_R_Execute  taskExec(TRAIL_MODE_ENTRY);
        
        if(!taskAct.Bind(GetPointer(ctx)) ||
           !taskExt.Bind(GetPointer(ctx)) ||
           !taskEval.Bind(GetPointer(ctx)) ||
           !taskExec.Bind(GetPointer(ctx))) {
            Print("  [FAIL] Failed to bind context to trailing entry tasks.");
            return false;
        }

        // Phase 1: Activation Test
        // ... (previous tests) ...
        pricer.OverridePrice(2347.50);
        taskAct.Execute(GetPointer(xp), GetPointer(ctx));
        ICXParam* pActive = ctx.GetParam("TE_Active_TEST-TE-01");
        if(IS_INVALID(pActive) || pActive.GetInt() != 1) {
            Print("  [PASS] TE not activated at 2347.50.");
        } else {
            Print("  [FAIL] TE activated prematurely at 2347.50.");
            allPassed = false;
        }
        
        pricer.OverridePrice(2346.50);
        taskAct.Execute(GetPointer(xp), GetPointer(ctx));
        pActive = ctx.GetParam("TE_Active_TEST-TE-01");
        if(IS_VALID(pActive) && pActive.GetInt() == 1) {
            Print("  [PASS] TE activated at 2346.50.");
        } else {
            allPassed = false;
        }
        
        // Phase 2: Improvement Test
        pricer.OverridePrice(2343.00);
        taskExt.Execute(GetPointer(xp), GetPointer(ctx));
        ICXParam* pExt = ctx.GetParam("TE_Extreme_TEST-TE-01");
        if(IS_VALID(pExt) && MathAbs(pExt.GetDouble() - 2343.00) < 0.01) {
            Print("  [PASS] Extreme updated to 2343.00.");
        } else {
            allPassed = false;
        }
        
        // Phase 3: Rebound Entry Test
        pricer.OverridePrice(2344.10);
        xp.SetInt(0);
        taskEval.Execute(GetPointer(xp), GetPointer(ctx));
        if(xp.GetInt() == 10) {
            Print("  [PASS] Rebound detected and market entry triggered.");
        } else {
            allPassed = false;
        }

        // Phase 4: Request Execution Test
        orderMgr.SetExecuteResult(true);
        taskExec.Execute(GetPointer(xp), GetPointer(ctx));
        if(sig.GetType() == ORDER_MARKET && sig.GetTag() == "ENTRY_TE_REBOUND") {
            Print("  [PASS] TE Rebound execution success (Market Entry).");
        } else {
            PrintFormat("  [FAIL] TE Rebound execution failed. Type: %d, Tag: %s", sig.GetType(), sig.GetTag());
            allPassed = false;
        }

        return allPassed;
    }
};

#endif