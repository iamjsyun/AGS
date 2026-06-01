#ifndef TEST_HISTORY_ANALYZER_MQH
#define TEST_HISTORY_ANALYZER_MQH

#include "..\Mocks\MockTerminalPlatform.mqh"
#include "..\..\03_Platform\Execution\Platform\CXHistoryAnalyzer.mqh"

/**
 * @class TestHistoryAnalyzer
 * @brief Unit test to verify CXHistoryAnalyzer's liquidation reason identification logic
 */
class TestHistoryAnalyzer {
public:
    static bool Run() {
        Print("--- Running TestHistoryAnalyzer (Subdivision Phase 1) ---");
        bool allPassed = true;

        MockTerminalPlatform terminal;
        CXHistoryAnalyzer analyzer(GetPointer(terminal));
        string reason;

        // 1. SL(Stop Loss) 청산 탐지 테스트
        terminal.InjectMockHistoryDeal(1001, 50001, DEAL_ENTRY_OUT, "sl triggered [sl]");
        if(analyzer.Analyze(50001, reason) == XE_CLOSED_SL) {
            Print("  [PASS] SL Closure Detection Success.");
        } else {
            PrintFormat("  [FAIL] SL Closure Detection Failed. Got Status:%d, Reason:%s", XE_CLOSED_SL, reason);
            allPassed = false;
        }

        // 2. TP(Take Profit) 청산 탐지 테스트
        terminal.InjectMockHistoryDeal(1002, 50002, DEAL_ENTRY_OUT, "tp hit [tp]");
        if(analyzer.Analyze(50002, reason) == XE_CLOSED_TP) {
            Print("  [PASS] TP Closure Detection Success.");
        } else {
            PrintFormat("  [FAIL] TP Closure Detection Failed. Got Status:%d, Reason:%s", XE_CLOSED_TP, reason);
            allPassed = false;
        }

        // 3. 수동 청산(Manual Close) 탐지 테스트
        terminal.InjectMockHistoryDeal(1003, 50003, DEAL_ENTRY_OUT, "manual close by mobile");
        if(analyzer.Analyze(50003, reason) == XE_CLOSED_SIGNAL) {
            Print("  [PASS] Manual Closure Detection Success.");
        } else {
            PrintFormat("  [FAIL] Manual Closure Detection Failed. Got Status:%d, Reason:%s", XE_CLOSED_SIGNAL, reason);
            allPassed = false;
        }

        // 4. 대기 주문 취소(Canceled) 탐지 테스트
        terminal.InjectMockHistoryOrder(60001, ORDER_STATE_CANCELED);
        if(analyzer.Analyze(60001, reason) == XE_CLOSED_SIGNAL) {
            Print("  [PASS] Pending Order Canceled Detection Success.");
        } else {
            PrintFormat("  [FAIL] Pending Order Canceled Detection Failed. Reason:%s", reason);
            allPassed = false;
        }

        // 5. 존재하지 않는 티켓 테스트
        if(analyzer.Analyze(99999, reason) == XE_UNKNOWN) {
            Print("  [PASS] Unknown Ticket Handling Success.");
        } else {
            Print("  [FAIL] Unknown Ticket Handling Failed.");
            allPassed = false;
        }

        if(allPassed) Print("--- TestHistoryAnalyzer: ALL PASSED ---");
        else Print("--- TestHistoryAnalyzer: SOME TESTS FAILED ---");

        return allPassed;
    }
};

#endif
