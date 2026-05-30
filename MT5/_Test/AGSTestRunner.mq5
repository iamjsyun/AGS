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
    if (TestEntryValidate::Run()) passed++; else failed++;
    if (TestSequenceDSL::Run()) passed++; else failed++;
    if (TestIntegritySimulation::Run()) passed++; else failed++;
    if (TestRedirectRecovery::Run()) passed++; else failed++;
    if (TestTrailingEntry::Run()) passed++; else failed++;
    if (TestTrailingStop::Run()) passed++; else failed++;
    if (TestManualExitBypass::Run()) passed++; else failed++;
    if (TestPendingSync::Run()) passed++; else failed++;
    if (TestActiveSync::Run()) passed++; else failed++;
    if (TestExitWorkflow::Run()) passed++; else failed++;
    if (TestIntentWatch::Run()) passed++; else failed++;
    if (TestPVBIntegrity::Run()) passed++; else failed++;
    
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
