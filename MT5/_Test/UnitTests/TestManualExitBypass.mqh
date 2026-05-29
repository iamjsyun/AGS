#ifndef TEST_MANUAL_EXIT_BYPASS_MQH
#define TEST_MANUAL_EXIT_BYPASS_MQH

#include "..\..\Workflow\Tasks\Active\CXTaskIntentWatch.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\Mocks\MockAssetManager.mqh"
#include "..\Mocks\MockRepository.mqh"

class TestManualExitBypass {
public:
    static bool Run() {
        Print("--- Running TestManualExitBypass ---");
        bool allPassed = true;
        
        CXContext ctx;
        MockAssetManager assetMgr;
        MockRepository repo;
        
        ctx.Register("asset_mgr", GetPointer(assetMgr));
        ctx.Register("repo", GetPointer(repo));
        
        CXParam xp;
        CXSignal sig;
        sig.SetSymbol("GOLDF#");
        sig.SetSid("TEST-MANUAL-01");
        sig.SetTicket(99001);
        sig.SetStatus(XE_EXECUTED);
        sig.SetXAExit(XA_RAW); // No exit intent yet
        xp.SetSignal(GetPointer(sig));
        
        CXTaskIntentWatch task;
        if(!task.Bind(GetPointer(ctx))) {
            Print("  [FAIL] Failed to bind context.");
            return false;
        }
        
        // 1. Asset exists -> Continue
        assetMgr.SetPositionExists(true);
        int res = task.Execute(GetPointer(xp), GetPointer(ctx));
        if(res == TASK_CONTINUE) {
            Print("  [PASS] Task continues when asset exists.");
        } else {
            PrintFormat("  [FAIL] Expected TASK_CONTINUE, got %d", res);
            allPassed = false;
        }
        
        // 2. Asset disappears (Manual Exit) -> Bypass to Closed
        assetMgr.SetPositionExists(false);
        res = task.Execute(GetPointer(xp), GetPointer(ctx));
        
        if(sig.GetStatus() == XE_CLOSED_MANUAL && sig.GetXAExit() == XA_CLOSED_COMPLETED) {
            Print("  [PASS] Manual exit bypass detected. Status: XE_CLOSED_MANUAL, XA_EXIT: XA_CLOSED_COMPLETED.");
        } else {
            PrintFormat("  [FAIL] Manual exit bypass failed. Status: %d, XA_EXIT: %d", sig.GetStatus(), sig.GetXAExit());
            allPassed = false;
        }

        return allPassed;
    }
};

#endif