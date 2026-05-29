//+------------------------------------------------------------------+
//|                                             TestIntentWatch.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Unit test for CXTaskIntentWatch                           |
//+------------------------------------------------------------------+
#ifndef TEST_INTENT_WATCH_MQH
#define TEST_INTENT_WATCH_MQH

#include "..\..\Workflow\Tasks\Active\CXTaskIntentWatch.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\Mocks\MockAssetManager.mqh"
#include "..\Mocks\MockRepository.mqh"

class TestIntentWatch {
public:
    static bool Run() {
        Print("--- Running TestIntentWatch (Manual/External Exit Watch) ---");
        bool allPassed = true;

        // 1. Setup Context & Mocks
        CXContext ctx;
        MockAssetManager assetMgr;
        MockRepository repo;

        ctx.Register("asset_mgr", GetPointer(assetMgr));
        ctx.Register("repo", GetPointer(repo));

        CXTaskIntentWatch task;
        if(!task.Bind(GetPointer(ctx))) {
            Print("  [FAIL] Failed to bind context to CXTaskIntentWatch.");
            return false;
        }

        //--------------------------------------------------------------
        // Case A: Manual Close Detected (Physical Asset Missing)
        //--------------------------------------------------------------
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-INTENT-01");
            sig.SetTicket(12345);
            sig.SetType(ORDER_MARKET);
            sig.SetStatus(XE_EXECUTED);
            xp.SetSignal(GetPointer(sig));

            // Simulating asset disappearance in terminal
            assetMgr.SetPositionExists(false); 

            int res = task.Execute(GetPointer(xp), GetPointer(ctx));

            if(res == SESSION_CLOSED && sig.GetStatus() == XE_CLOSED_MANUAL && sig.GetXAExit() == XA_CLOSED_COMPLETED) {
                Print("  [PASS] Case A: Manual close detected and session finalized.");
            } else {
                PrintFormat("  [FAIL] Case A: Expected res=30, status=24, xa_exit=2. Got res=%d, status=%d, xa_exit=%d", 
                            res, sig.GetStatus(), sig.GetXAExit());
                allPassed = false;
            }
        }

        //--------------------------------------------------------------
        // Case B: External Exit Intent (Synchronized from DB)
        //--------------------------------------------------------------
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-INTENT-02");
            sig.SetTicket(23456);
            sig.SetType(ORDER_MARKET);
            sig.SetStatus(XE_EXECUTED);
            sig.SetXAExit(XA_RAW); // Engine thinks it's still active
            xp.SetSignal(GetPointer(sig));

            // Terminal asset still exists
            assetMgr.SetPositionExists(true); 

            // Simulate DB has XA_ACTIVE intent
            CXSignal* dbSig = new CXSignal();
            dbSig.SetSid("TEST-INTENT-02");
            dbSig.SetXAExit(XA_ACTIVE);
            repo.SetMockSignal(dbSig);

            int res = task.Execute(GetPointer(xp), GetPointer(ctx));

            if(res == SESSION_LIQUIDATING && sig.GetXAExit() == XA_ACTIVE) {
                Print("  [PASS] Case B: External exit intent detected and synchronized.");
            } else {
                PrintFormat("  [FAIL] Case B: Expected res=20, xa_exit=1. Got res=%d, xa_exit=%d", 
                            res, sig.GetXAExit());
                allPassed = false;
            }
        }

        return allPassed;
    }
};

#endif
