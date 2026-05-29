//+------------------------------------------------------------------+
//|                                             TestPendingSync.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Unit test for CXTaskPending_V_Sync                        |
//+------------------------------------------------------------------+
#ifndef TEST_PENDING_SYNC_MQH
#define TEST_PENDING_SYNC_MQH

#include "..\..\Workflow\Tasks\Pending\CXTaskPending_V_Sync.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\Mocks\MockAssetManager.mqh"
#include "..\Mocks\MockRepository.mqh"

class TestPendingSync {
public:
    static bool Run() {
        Print("--- Running TestPendingSync (CXTaskPending_V_Sync) ---");
        bool allPassed = true;

        // 1. Setup Context & Mocks
        CXContext ctx;
        MockAssetManager assetMgr;
        MockRepository repo;
        
        ctx.Register("asset_mgr", GetPointer(assetMgr));
        ctx.Register("repo", GetPointer(repo));

        CXTaskPending_V_Sync task;
        if(!task.Bind(GetPointer(ctx))) {
            Print("  [FAIL] Failed to bind context to CXTaskPending_V_Sync.");
            return false;
        }

        // Test Case 1: Exit intent detected (xa_exit == XA_ACTIVE). Should transition to SESSION_LIQUIDATING.
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-PEND-01");
            sig.SetXAExit(XA_ACTIVE); // 1
            xp.SetSignal(GetPointer(sig));

            int result = task.Execute(GetPointer(xp), GetPointer(ctx));
            if(result == SESSION_LIQUIDATING) {
                Print("  [PASS] Exit command detected, transitioned to SESSION_LIQUIDATING.");
            } else {
                PrintFormat("  [FAIL] Expected SESSION_LIQUIDATING, got %d", result);
                allPassed = false;
            }
        }

        // Test Case 2: Order filled (IsPositionExists == true). Should transition to SESSION_ACTIVE and status to XE_EXECUTED.
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-PEND-02");
            sig.SetTicket(60001);
            sig.SetStatus(XE_READY);
            xp.SetSignal(GetPointer(sig));

            assetMgr.SetPositionExists(true);

            int result = task.Execute(GetPointer(xp), GetPointer(ctx));
            if(result == SESSION_ACTIVE && sig.GetStatus() == XE_EXECUTED) {
                Print("  [PASS] Order filled, transitioned to SESSION_ACTIVE, status updated to XE_EXECUTED.");
            } else {
                PrintFormat("  [FAIL] Expected SESSION_ACTIVE & XE_EXECUTED. Result: %d, Status: %d", result, sig.GetStatus());
                allPassed = false;
            }
        }

        // Test Case 3: Signal status XE_ERROR. Should transition to SESSION_ERROR.
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-PEND-03");
            sig.SetTicket(60002);
            sig.SetStatus(XE_ERROR);
            xp.SetSignal(GetPointer(sig));

            assetMgr.SetPositionExists(false);

            int result = task.Execute(GetPointer(xp), GetPointer(ctx));
            if(result == SESSION_ERROR) {
                Print("  [PASS] Signal in XE_ERROR, transitioned to SESSION_ERROR.");
            } else {
                PrintFormat("  [FAIL] Expected SESSION_ERROR, got %d", result);
                allPassed = false;
            }
        }

        // Test Case 4: Signal status already >= XE_EXECUTED. Should transition to SESSION_ACTIVE.
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-PEND-04");
            sig.SetTicket(60003);
            sig.SetStatus(XE_EXECUTED);
            xp.SetSignal(GetPointer(sig));

            assetMgr.SetPositionExists(false);

            int result = task.Execute(GetPointer(xp), GetPointer(ctx));
            if(result == SESSION_ACTIVE) {
                Print("  [PASS] Status already executed, transitioned to SESSION_ACTIVE.");
            } else {
                PrintFormat("  [FAIL] Expected SESSION_ACTIVE, got %d", result);
                allPassed = false;
            }
        }

        // Test Case 5: No ticket yet (ticket <= 0). Should yield/break with TASK_BREAK.
        {
            CXParam xp;
            CXSignal sig;
            sig.SetSid("TEST-PEND-05");
            sig.SetTicket(0);
            sig.SetStatus(XE_READY);
            xp.SetSignal(GetPointer(sig));

            assetMgr.SetPositionExists(false);

            int result = task.Execute(GetPointer(xp), GetPointer(ctx));
            if(result == TASK_BREAK) {
                Print("  [PASS] No ticket yet, returned TASK_BREAK.");
            } else {
                PrintFormat("  [FAIL] Expected TASK_BREAK, got %d", result);
                allPassed = false;
            }
        }

        return allPassed;
    }
};

#endif
