//+------------------------------------------------------------------+
//|                                            TestExitWorkflow.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Unit and Integration test for exit-phase tasks            |
//+------------------------------------------------------------------+
#ifndef TEST_EXIT_WORKFLOW_MQH
#define TEST_EXIT_WORKFLOW_MQH

#include "..\..\Workflow\Tasks\Exit\CXTaskExit_L_Prepare.mqh"
#include "..\..\Workflow\Tasks\Exit\CXTaskExit_P_Lock.mqh"
#include "..\..\Workflow\Tasks\Exit\CXTaskExit_R_Order.mqh"
#include "..\..\Workflow\Tasks\Exit\CXTaskExit_V_Error.mqh"
#include "..\..\Workflow\Tasks\Exit\CXTaskExit_V_Terminal.mqh"
#include "..\..\Workflow\Tasks\Exit\CXTaskExit_P_Finalize.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\Mocks\MockTerminalPlatform.mqh"
#include "..\Mocks\MockAssetManager.mqh"
#include "..\Mocks\MockRepository.mqh"
#include "..\Mocks\MockExitManager.mqh"

class TestExitWorkflow {
public:
    static bool Run() {
        Print("--- Running TestExitWorkflow (Exit-Phase Integration) ---");
        bool allPassed = true;

        //--------------------------------------------------------------
        // Scenario A: Normal Exit Flow (Complete Path to SESSION_CLOSED)
        //--------------------------------------------------------------
        {
            CXContext ctx;
            MockTerminalPlatform terminal;
            MockAssetManager assetMgr;
            MockRepository repo;
            MockExitManager exitMgr(GetPointer(terminal));

            ctx.Register("terminal_platform", GetPointer(terminal));
            ctx.Register("asset_mgr", GetPointer(assetMgr));
            ctx.Register("repo", GetPointer(repo));
            ctx.Register("exit_mgr", GetPointer(exitMgr));

            CXTaskExit_L_Prepare  tPrepare;
            CXTaskExit_P_Lock     tLock;
            CXTaskExit_R_Order    tOrder;
            CXTaskExit_V_Error    tError;
            CXTaskExit_V_Terminal tTermVal;
            CXTaskExit_P_Finalize tFinalize;

            if(!tPrepare.Bind(GetPointer(ctx)) || !tLock.Bind(GetPointer(ctx)) || 
               !tOrder.Bind(GetPointer(ctx))   || !tError.Bind(GetPointer(ctx)) || 
               !tTermVal.Bind(GetPointer(ctx)) || !tFinalize.Bind(GetPointer(ctx))) {
                Print("  [FAIL] Scenario A: Failed to bind tasks.");
                return false;
            }

            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-EXIT-A");
            sig.SetTicket(80001);
            sig.SetType(ORDER_TYPE_BUY);
            sig.SetStatus(XE_EXECUTED);
            sig.SetXAExit(XA_ACTIVE); // Trigger Liquidation (1)
            xp.SetSignal(GetPointer(sig));

            // Inject position into virtual terminal/broker
            terminal.InjectMockAsset(true, 80001, "TEST-EXIT-A", "GOLDF#", 1001, CX_DIR_BUY, 0.1, 2350.00, 0, 0);
            assetMgr.SetPositionExists(true);
            exitMgr.SetSweepResult(true);

            // Run normal sequential pipe
            int res1 = tPrepare.Execute(GetPointer(xp), GetPointer(ctx));
            int res2 = tLock.Execute(GetPointer(xp), GetPointer(ctx));
            int res3 = tOrder.Execute(GetPointer(xp), GetPointer(ctx)); // Should trigger SweepBySid
            
            // Post order sweep, simulate terminal absence
            assetMgr.SetPositionExists(false); 
            
            int res4 = tError.Execute(GetPointer(xp), GetPointer(ctx));
            int res5 = tTermVal.Execute(GetPointer(xp), GetPointer(ctx));
            int res6 = tFinalize.Execute(GetPointer(xp), GetPointer(ctx));

            bool stepResultsOk = (res1 == TASK_CONTINUE && res2 == TASK_CONTINUE && 
                                  res3 == TASK_CONTINUE && res4 == TASK_CONTINUE && 
                                  res5 == TASK_CONTINUE && res6 == SESSION_CLOSED);

            if(stepResultsOk && sig.GetXAExit() == XA_CLOSED_COMPLETED && sig.GetStatus() == XE_CLOSED_SIGNAL) {
                Print("  [PASS] Scenario A: Exit chain executed normally and finalized successfully.");
            } else {
                PrintFormat("  [FAIL] Scenario A: Exit chain failed. Res: Prepare=%d Lock=%d Order=%d Error=%d Term=%d Final=%d. Final XAExit:%d Status:%d",
                            res1, res2, res3, res4, res5, res6, sig.GetXAExit(), sig.GetStatus());
                allPassed = false;
            }
        }

        //--------------------------------------------------------------
        // Scenario B: Broker Offline (Sweep fail -> TASK_YIELD)
        //--------------------------------------------------------------
        {
            CXContext ctx;
            MockTerminalPlatform terminal;
            MockAssetManager assetMgr;
            MockRepository repo;
            MockExitManager exitMgr(GetPointer(terminal));

            ctx.Register("terminal_platform", GetPointer(terminal));
            ctx.Register("asset_mgr", GetPointer(assetMgr));
            ctx.Register("repo", GetPointer(repo));
            ctx.Register("exit_mgr", GetPointer(exitMgr));

            CXTaskExit_R_Order tOrder;
            if(!tOrder.Bind(GetPointer(ctx))) {
                Print("  [FAIL] Scenario B: Failed to bind tOrder.");
                return false;
            }

            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-EXIT-B");
            sig.SetTicket(80002);
            sig.SetType(ORDER_TYPE_BUY);
            sig.SetStatus(XE_EXECUTED);
            sig.SetXAExit(XA_ACTIVE);
            xp.SetSignal(GetPointer(sig));

            terminal.InjectMockAsset(true, 80002, "TEST-EXIT-B", "GOLDF#", 1001, CX_DIR_BUY, 0.1, 2350.00, 0, 0);
            assetMgr.SetPositionExists(true);
            exitMgr.SetSweepResult(false); // Broker offline simulation

            int result = tOrder.Execute(GetPointer(xp), GetPointer(ctx));
            if(result == TASK_YIELD && xp.GetInt() != 3) {
                Print("  [PASS] Scenario B: Sweep failure correctly yielded for broker reconnection retry.");
            } else {
                PrintFormat("  [FAIL] Scenario B: Expected TASK_YIELD and xp.GetInt() != 3. Got result:%d, xp.GetInt():%d", result, xp.GetInt());
                allPassed = false;
            }
        }

        //--------------------------------------------------------------
        // Scenario C: Absence Verification Timeout (Asset remains)
        //--------------------------------------------------------------
        {
            CXContext ctx;
            MockTerminalPlatform terminal;
            MockAssetManager assetMgr;
            MockRepository repo;

            ctx.Register("terminal_platform", GetPointer(terminal));
            ctx.Register("asset_mgr", GetPointer(assetMgr));
            ctx.Register("repo", GetPointer(repo));

            CXTaskExit_V_Terminal tTermVal;
            if(!tTermVal.Bind(GetPointer(ctx))) {
                Print("  [FAIL] Scenario C: Failed to bind tTermVal.");
                return false;
            }

            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-EXIT-C");
            sig.SetTicket(80003);
            sig.SetType(ORDER_TYPE_BUY);
            sig.SetStatus(XE_EXECUTED);
            sig.SetXAExit(XA_ACTIVE);
            xp.SetSignal(GetPointer(sig));

            // Asset still exists in terminal and won't go away
            assetMgr.SetPositionExists(true);

            int pulseCount = 0;
            int res = TASK_CONTINUE;
            
            // Loop 6 times (Max retry limit is 5)
            for(int i = 0; i < 6; i++) {
                res = tTermVal.Execute(GetPointer(xp), GetPointer(ctx));
                pulseCount++;
                if(res == SESSION_ERROR) {
                    break;
                }
            }

            if(res == SESSION_ERROR && pulseCount == 6 && tTermVal.GetRetryCount() > 5) {
                Print("  [PASS] Scenario C: Session correctly errored out after 5 consecutive absence check failures.");
            } else {
                PrintFormat("  [FAIL] Scenario C: Expected SESSION_ERROR at pulse 6. Got result:%d, PulseCount:%d, RetryCount:%d",
                            res, pulseCount, tTermVal.GetRetryCount());
                allPassed = false;
            }
        }

        return allPassed;
    }
};

#endif
