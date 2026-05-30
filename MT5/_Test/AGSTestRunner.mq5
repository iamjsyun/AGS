//+------------------------------------------------------------------+
//|                                              AGSTestRunner.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//|                    Task-Level Unit Test Runner EA for ATSE       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/google-gemini/gemini-cli"
#property version   "1.00"
#property strict

#include "UnitTests\TestEntryValidate.mqh"
#include "UnitTests\TestSequenceDSL.mqh"
#include "UnitTests\TestIntegritySimulation.mqh"
#include "UnitTests\TestRedirectRecovery.mqh"
#include "UnitTests\TestTrailingEntry.mqh"
#include "UnitTests\TestTrailingStop.mqh"
#include "UnitTests\TestManualExitBypass.mqh"
#include "UnitTests\TestPendingSync.mqh"
#include "UnitTests\TestActiveSync.mqh"
#include "UnitTests\TestExitWorkflow.mqh"
#include "UnitTests\TestIntentWatch.mqh"
#include "UnitTests\TestPVBIntegrity.mqh"

void CloseAllChartsExceptCurrent() {
    long currChart = ChartID();
    long chartId = ChartFirst();
    int limit = 100;
    while(chartId >= 0 && limit > 0) {
        long nextChart = ChartNext(chartId);
        if(chartId != currChart) {
            ChartClose(chartId);
        }
        chartId = nextChart;
        limit--;
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    CloseAllChartsExceptCurrent();

    Print("==================================================");
    Print("Starting ATSE Unit Tests (Task-Level Isolation)...");
    Print("==================================================");
    
    int passed = 0;
    int failed = 0;
    
    // Run Scenarios
    bool r_EntryValidate = TestEntryValidate::Run();
    bool r_SequenceDSL = TestSequenceDSL::Run();
    bool r_IntegritySimulation = TestIntegritySimulation::Run();
    bool r_RedirectRecovery = TestRedirectRecovery::Run();
    bool r_TrailingEntry = TestTrailingEntry::Run();
    bool r_TrailingStop = TestTrailingStop::Run();
    bool r_ManualExitBypass = TestManualExitBypass::Run();
    bool r_PendingSync = TestPendingSync::Run();
    bool r_ActiveSync = TestActiveSync::Run();
    bool r_ExitWorkflow = TestExitWorkflow::Run();
    bool r_IntentWatch = TestIntentWatch::Run();
    bool r_PVBIntegrity = TestPVBIntegrity::Run();

    if (r_EntryValidate) passed++; else failed++;
    if (r_SequenceDSL) passed++; else failed++;
    if (r_IntegritySimulation) passed++; else failed++;
    if (r_RedirectRecovery) passed++; else failed++;
    if (r_TrailingEntry) passed++; else failed++;
    if (r_TrailingStop) passed++; else failed++;
    if (r_ManualExitBypass) passed++; else failed++;
    if (r_PendingSync) passed++; else failed++;
    if (r_ActiveSync) passed++; else failed++;
    if (r_ExitWorkflow) passed++; else failed++;
    if (r_IntentWatch) passed++; else failed++;
    if (r_PVBIntegrity) passed++; else failed++;
    
    // Add more test classes here...
    
    Print("==================================================");
    PrintFormat("Test Run Complete. Suites Passed: %d, Suites Failed: %d", passed, failed);
    Print("==================================================");

    // [v1.2 CI Integration] 결과 파일 출력
    int resHandle = FileOpen("AGS\\scenario_result.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
    if(resHandle != INVALID_HANDLE) {
        FileWriteString(resHandle, "id=UNIT_TEST_SUITE\r\n");
        FileWriteString(resHandle, StringFormat("passed=%d\r\n", passed));
        FileWriteString(resHandle, StringFormat("failed=%d\r\n", failed));
        FileWriteString(resHandle, StringFormat("status=%s\r\n", (failed == 0) ? "PASSED" : "FAILED"));
        FileWriteString(resHandle, StringFormat("TestEntryValidate=%s\r\n", r_EntryValidate ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestSequenceDSL=%s\r\n", r_SequenceDSL ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestIntegritySimulation=%s\r\n", r_IntegritySimulation ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestRedirectRecovery=%s\r\n", r_RedirectRecovery ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestTrailingEntry=%s\r\n", r_TrailingEntry ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestTrailingStop=%s\r\n", r_TrailingStop ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestManualExitBypass=%s\r\n", r_ManualExitBypass ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestPendingSync=%s\r\n", r_PendingSync ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestActiveSync=%s\r\n", r_ActiveSync ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestExitWorkflow=%s\r\n", r_ExitWorkflow ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestIntentWatch=%s\r\n", r_IntentWatch ? "OK" : "FAIL"));
        FileWriteString(resHandle, StringFormat("TestPVBIntegrity=%s\r\n", r_PVBIntegrity ? "OK" : "FAIL"));
        FileClose(resHandle);
    }
    
    // 테스트 완료 후 EA 자동 종료 (불필요한 리소스 점유 방지)
    ExpertRemove();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("ATSE Unit Tests EA Unloaded.");
}

//+------------------------------------------------------------------+
//| Expert tick function (Not used in Test Runner)                   |
//+------------------------------------------------------------------+
void OnTick() {}
