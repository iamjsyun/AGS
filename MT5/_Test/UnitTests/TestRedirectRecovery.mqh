#ifndef TEST_REDIRECT_RECOVERY_MQH
#define TEST_REDIRECT_RECOVERY_MQH

#include "..\..\Workflow\Tasks\Pending\CXTaskPending_V_Sync.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\Mocks\MockAssetManager.mqh"
#include "..\Mocks\MockRepository.mqh"

class TestRedirectRecovery {
public:
    static bool Run() {
        Print("--- Running TestRedirectRecovery (CXTaskPending_V_Sync States Sync/Redirect) ---");
        bool allPassed = true;
        
        CXContext ctx;
        MockAssetManager* assetMgr = new MockAssetManager();
        MockRepository* repo = new MockRepository();
        ctx.Register("asset_mgr", assetMgr);
        ctx.Register("repo", repo);
        
        CXParam xp;
        CXSignal* sig = new CXSignal();
        xp.SetSignal(sig);
        
        CXTaskPending_V_Sync task;
        if(!task.Bind(GetPointer(ctx))) {
            Print("  [FAIL] Failed to bind context.");
            delete assetMgr;
            delete repo;
            delete sig;
            return false;
        }
        
        // Test Case 1: Exit Intent detected (xa_exit == XA_ACTIVE). Should return SESSION_LIQUIDATING (20).
        sig.Reset();
        sig.SetXAExit(XA_ACTIVE); // 1
        int result = task.Execute(GetPointer(xp), GetPointer(ctx));
        if (result == SESSION_LIQUIDATING) {
            Print("  [PASS] Exit intent detected. Returned SESSION_LIQUIDATING.");
        } else {
            PrintFormat("  [FAIL] Expected SESSION_LIQUIDATING(%d), got %d", SESSION_LIQUIDATING, result);
            allPassed = false;
        }

        // Test Case 2: Signal in Error (xe_status == XE_ERROR). Should return SESSION_ERROR (99).
        sig.Reset();
        sig.SetStatus(XE_ERROR); // 99
        result = task.Execute(GetPointer(xp), GetPointer(ctx));
        if (result == SESSION_ERROR) {
            Print("  [PASS] Signal in XE_ERROR. Returned SESSION_ERROR.");
        } else {
            PrintFormat("  [FAIL] Expected SESSION_ERROR(%d), got %d", SESSION_ERROR, result);
            allPassed = false;
        }

        // Test Case 3: Already Executed (xe_status == XE_EXECUTED). Should return SESSION_ACTIVE (10).
        sig.Reset();
        sig.SetStatus(XE_EXECUTED); // 10
        result = task.Execute(GetPointer(xp), GetPointer(ctx));
        if (result == SESSION_ACTIVE) {
            Print("  [PASS] Signal already XE_EXECUTED. Returned SESSION_ACTIVE.");
        } else {
            PrintFormat("  [FAIL] Expected SESSION_ACTIVE(%d), got %d", SESSION_ACTIVE, result);
            allPassed = false;
        }

        // Test Case 4: Order filled on terminal (IsPositionExists == true). Should update status to XE_EXECUTED and return SESSION_ACTIVE (10).
        sig.Reset();
        sig.SetTicket(88001);
        sig.SetStatus(XE_PENDING_PLACED);
        assetMgr.SetPositionExists(true);
        result = task.Execute(GetPointer(xp), GetPointer(ctx));
        if (result == SESSION_ACTIVE && sig.GetStatus() == XE_EXECUTED) {
            Print("  [PASS] Order filled on terminal. Status updated to XE_EXECUTED, returned SESSION_ACTIVE.");
        } else {
            PrintFormat("  [FAIL] Expected status XE_EXECUTED(%d) and return SESSION_ACTIVE(%d). Got status %d, result %d",
                        XE_EXECUTED, SESSION_ACTIVE, sig.GetStatus(), result);
            allPassed = false;
        }
        
        delete assetMgr;
        delete repo;
        delete sig;
        
        return allPassed;
    }
};

#endif
