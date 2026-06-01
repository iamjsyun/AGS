#ifndef TEST_ENTRY_VALIDATE_MQH
#define TEST_ENTRY_VALIDATE_MQH

#include "..\..\..\03_Platform\Execution\CXEntryManager.mqh"
#include "..\..\..\02_Domain\Models\CXContext.mqh"
#include "..\..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\..\02_Domain\Models\CXSignal.mqh"
#include "..\..\Mocks\MockTerminalPlatform.mqh"

class TestEntryValidate {
public:
    static bool Run() {
        Print("--- Running TestEntryValidate (CXEntryManager Integrity Gatekeeper) ---");
        bool allPassed = true;
        
        // 1. Setup Context & Mocks
        CXContext ctx;
        MockTerminalPlatform terminal;
        ctx.Register("terminal_platform", GetPointer(terminal));
        
        CXParam xp;
        CXSignal sig;
        sig.SetSid("TEST-GATE-01");
        sig.SetMagic(1001);
        sig.SetSymbol("GOLD#");
        xp.SetSignal(GetPointer(sig));
        
        CXEntryManager manager(GetPointer(ctx));
        
        // Test Case 1: No asset in terminal. Validation returns 0.
        int result = manager.ValidateTerminalIntegrity(GetPointer(xp));
        if(result == 0) {
            Print("  [PASS] No asset found, ValidateTerminalIntegrity returned 0.");
        } else {
            PrintFormat("  [FAIL] Expected 0, got %d", result);
            allPassed = false;
        }
        
        // Test Case 2: Asset exists in terminal. Should return SESSION_PENDING (binding).
        terminal.InjectMockAsset(true, 77001, "TEST-GATE-01", "GOLD#", 1001, CX_DIR_BUY, 0.1, 2350.00, 0, 0);
        result = manager.ValidateTerminalIntegrity(GetPointer(xp));
        
        if(result == SESSION_PENDING && sig.GetTicket() == 77001) {
            Print("  [PASS] Asset found, bound to ticket 77001, returned SESSION_PENDING.");
        } else {
            PrintFormat("  [FAIL] Expected SESSION_PENDING with bound ticket 77001, got result %d, ticket %I64u", result, sig.GetTicket());
            allPassed = false;
        }
        
        return allPassed;
    }
};

#endif
