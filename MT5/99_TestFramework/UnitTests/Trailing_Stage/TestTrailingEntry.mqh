#ifndef TEST_TRAILING_ENTRY_MQH
#define TEST_TRAILING_ENTRY_MQH

#include "..\..\..\07_Flow\Tasks\Trailing\CXTaskTrail_V_Activate.mqh"
#include "..\..\..\07_Flow\Tasks\Trailing\CXTaskTrail_V_Extremum.mqh"
#include "..\..\..\07_Flow\Tasks\Trailing\CXTaskTrail_L_Evaluate.mqh"
#include "..\..\..\02_Domain\Models\CXContext.mqh"
#include "..\..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\..\02_Domain\Models\CXSignal.mqh"
#include "..\..\Mocks\MockPriceManager.mqh"
#include "..\..\Mocks\MockTerminalPlatform.mqh"
#include "..\..\Scenarios\CXVirtualPricer.mqh"

#include "..\..\..\07_Flow\Tasks\Trailing\CXTaskTrail_R_Execute.mqh"
#include "..\..\Mocks\MockOrderManager.mqh"
#include "..\..\Mocks\MockSymbolManager.mqh"

class TestTrailingEntry {
public:
    static bool Run() {
        Print("--- Running TestTrailingEntry (Trailing Entry Logic) ---");
        bool allPassed = true;

        //--------------------------------------------------------------
        // Scenario 1: Tracking bottom and Rebound (Market Buy)
        //--------------------------------------------------------------
        {
            CXContext ctx;
            MockPriceManager priceMgr(GetPointer(ctx));
            MockTerminalPlatform terminal;
            CXVirtualPricer pricer("GOLD#", 0.01);
            MockOrderManager orderMgr;
            MockSymbolManager symMgr;

            ctx.Register("price_mgr", GetPointer(priceMgr));
            ctx.Register("terminal_platform", GetPointer(terminal));
            ctx.Register("order_mgr", GetPointer(orderMgr));
            ctx.Register("sym_mgr", GetPointer(symMgr));

            priceMgr.SetPricer(GetPointer(pricer));
            symMgr.SetPoint("GOLD#", 0.01);

            CXTaskTrail_V_Activate tActivate(TRAIL_MODE_ENTRY);
            CXTaskTrail_V_Extremum tExtremum(TRAIL_MODE_ENTRY);
            CXTaskTrail_L_Evaluate tEvaluate(TRAIL_MODE_ENTRY);
            CXTaskTrail_R_Execute  tExecute(TRAIL_MODE_ENTRY);

            tActivate.Bind(GetPointer(ctx));
            tExtremum.Bind(GetPointer(ctx));
            tEvaluate.Bind(GetPointer(ctx));
            tExecute.Bind(GetPointer(ctx));

            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-TE-01");
            sig.SetSymbol("GOLD#");
            sig.SetMagic(1001);
            sig.SetDir(CX_DIR_BUY);
            sig.SetTEStart(300); // 3.00
            sig.SetTEStep(100);  // 1.00
            sig.SetPriceSignal(2350.00);
            sig.SetPriceOpen(2350.00);
            sig.SetStatus(XE_PENDING_PLACED);
            sig.SetTicket(99001);
            xp.SetSignal(GetPointer(sig));

            // 1. Activate
            pricer.SetPrice(2346.50); // Signal (2350) - 3.50 (350 pts) -> Activated!
            tActivate.Execute(GetPointer(xp), GetPointer(ctx));
            
            // 2. Track Bottom
            pricer.SetPrice(2344.00); 
            tExtremum.Execute(GetPointer(xp), GetPointer(ctx)); // Extremum = 2344.00
            
            // 3. Evaluation (No rebound yet)
            pricer.SetPrice(2344.50); // Rebound 0.50 < 1.00
            int res = tEvaluate.Execute(GetPointer(xp), GetPointer(ctx));
            
            if(res == TASK_CONTINUE) {
                Print("  [PASS] Scenario 1: Tracking bottom correctly, no premature execution.");
            } else {
                PrintFormat("  [FAIL] Scenario 1: Evaluation failed. Expected CONTINUE, got %d", res);
                allPassed = false;
            }

            // 4. Execution (Rebound triggered)
            pricer.SetPrice(2345.10); // Rebound 1.10 > 1.00 (TEStep) -> Triggered!
            tExtremum.Execute(GetPointer(xp), GetPointer(ctx));
            res = tEvaluate.Execute(GetPointer(xp), GetPointer(ctx));
            
            if(res == TASK_CONTINUE) { // Evaluate sets flag and returns continue
                tExecute.Execute(GetPointer(xp), GetPointer(ctx));
                if(orderMgr.GetLastAction() == "ExecuteEntry" && orderMgr.GetLastTicket() == 99001) {
                     Print("  [PASS] Scenario 1: Rebound detected, pending order deleted and market execution triggered.");
                } else {
                     PrintFormat("  [FAIL] Scenario 1: Order manager action mismatch. Got: %s", orderMgr.GetLastAction());
                     allPassed = false;
                }
            } else {
                PrintFormat("  [FAIL] Scenario 1: Rebound not detected. Res: %d", res);
                allPassed = false;
            }
        }

        return allPassed;
    }
};

#endif
