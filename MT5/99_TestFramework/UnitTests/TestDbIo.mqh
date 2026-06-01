#ifndef TEST_DB_IO_MQH
#define TEST_DB_IO_MQH

#include "..\..\01_Core\DB\CXDatabase.mqh"
#include "..\..\01_Core\DB\CXSignalRepository.mqh"
#include "..\..\02_Domain\Models\CXSignal.mqh"

/**
 * @class TestDbIo
 * @brief DB I/O automated creation and terminal connection state verification
 */
class TestDbIo {
public:
    static bool Run() {
        Print("DEBUG: TestDbIo::Run() started");
        bool allPassed = true;
        bool isTester = (bool)MQLInfoInteger(MQL_TESTER);
        
        if(isTester) {
            Print("DEBUG: [INFO] Running in Strategy Tester mode.");
        }

        // 1. Check terminal connection status
        bool isConnected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
        if(isConnected) {
            PrintFormat("DEBUG: [PASS] Terminal is CONNECTED to %s", AccountInfoString(ACCOUNT_SERVER));
        } else {
            Print("DEBUG: [WARN] Terminal is NOT CONNECTED!");
        }

        // 2. DB automatic creation and I/O test
        CXDatabase db;
        if(db.Open("TestUnit.db", false)) {
            Print("  [PASS] DB Connection Success: TestUnit.db is ready.");
        } else {
            Print("  [FAIL] DB Connection Failed: Could not open/create TestUnit.db");
            return false;
        }

        CXSignalRepository repo(GetPointer(db));
        
        // 데이터 삽입 테스트
        CXSignal sig;
        sig.SetSid("CONN-TEST-260531");
        sig.SetSymbol("GOLD#");
        sig.SetType(ORDER_TYPE_BUY);
        sig.SetLot(0.1);
        
        repo.SaveSignal(GetPointer(sig));
        Print("DEBUG: [PASS] Signal save call finished.");

        // 데이터 조회 테스트
        string status = repo.GetStatusBySid("CONN-TEST-260531");
        if(status != "") {
             Print("DEBUG: [PASS] Signal retrieved from DB successfully.");
        } else {
             Print("DEBUG: [FAIL] Failed to retrieve signal from DB.");
             allPassed = false;
        }

        db.Close();
        PrintFormat("DEBUG: TestDbIo::Run() finished with result %d", allPassed);
        return allPassed;
    }
};

#endif
