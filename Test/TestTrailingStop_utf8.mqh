#ifndef TEST_TRAILING_STOP_MQH
#define TEST_TRAILING_STOP_MQH

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

class TestTrailingStop {
public:
    static bool Run() {
        Print("--- Running TestTrailingStop (Trailing Stop Logic) ---");
        bool allPassed = true;

        //--------------------------------------------------------------
        // Scenario 1: Profit tracking and SL update (Position Buy)
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

            CXTaskTrail_V_Activate tActivate(TRAIL_MODE_EXIT);
            CXTaskTrail_V_Extremum tExtremum(TRAIL_MODE_EXIT);
            CXTaskTrail_L_Evaluate tEvaluate(TRAIL_MODE_EXIT);
            CXTaskTrail_R_Execute  tExecute(TRAIL_MODE_EXIT);

            tActivate.Bind(GetPointer(ctx));
            tExtremum.Bind(GetPointer(ctx));
            tEvaluate.Bind(GetPointer(ctx));
            tExecute.Bind(GetPointer(ctx));

            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-TS-01");
            sig.SetSymbol("GOLD#");
            sig.SetMagic(1001);
            sig.SetDir(CX_DIR_BUY);
            sig.SetTSStart(1000); // 10.00 profit
            sig.SetTSStep(500);   // 5.00 trailing distance
            sig.SetPriceOpen(2340.00);
            sig.SetStatus(XE_EXECUTED);
            sig.SetTicket(99002);
            xp.SetSignal(GetPointer(sig));

            // 1. Activate
            pricer.SetPrice(2350.50); // Profit 10.50 pts > 10.00 -> Activated!
            tActivate.Execute(GetPointer(xp), GetPointer(ctx));
            
            // 2. Track Peak
            pricer.SetPrice(2355.00); // New Peak
            tExtremum.Execute(GetPointer(xp), GetPointer(ctx));
            
            // 3. Evaluation & Execution (SL Update)
            // Target SL = Peak (2355.00) - Distance (5.00) = 2350.00
            int res = tEvaluate.Execute(GetPointer(xp), GetPointer(ctx));
            tExecute.Execute(GetPointer(xp), GetPointer(ctx));

            if(orderMgr.GetLastAction() == "PositionModify" && orderMgr.GetLastTicket() == 99002 && 
               MathAbs(orderMgr.GetLastSL() - 2350.00) < 0.001) {
                Print("  [PASS] Scenario 1: SL updated correctly following profit peak.");
            } else {
                PrintFormat("  [FAIL] Scenario 1: SL update mismatch. Action:%s SL:%.2f", orderMgr.GetLastAction(), orderMgr.GetLastSL());
                allPassed = false;
            }
        }

        return allPassed;
    }
};

#endif
