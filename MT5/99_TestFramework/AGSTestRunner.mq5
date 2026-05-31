//+------------------------------------------------------------------+
//|                                              AGSTestRunner.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//|                    Task-Level Unit Test Runner EA for ATSE       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/google-gemini/gemini-cli"
#property version   "1.06"
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
#include "UnitTests\TestHistoryAnalyzer.mqh"
#include "UnitTests\TestOrderValidator.mqh"
#include "UnitTests\TestPriceRiskSubdivision.mqh"
#include "UnitTests\TestSmartPVB.mqh"

// Atomic Tests (Hyper-Atomization)
#include "UnitTests\Atomic\TestTickScraper.mqh"
#include "UnitTests\Atomic\TestPriceInverter.mqh"
#include "UnitTests\Atomic\TestLotStepAligner.mqh"
#include "UnitTests\Atomic\TestStopsGuard.mqh"

void CloseAllChartsExceptCurrent() {
    long currChart = ChartID();
    long chartId = ChartFirst();
    int limit = 100;
    while(chartId >= 0 && limit > 0) {
        long nextChart = ChartNext(chartId);
        if(chartId != currChart) { ChartClose(chartId); }
        chartId = nextChart;
        limit--;
    }
}

int OnInit() {
    CloseAllChartsExceptCurrent();
    Print("==================================================");
    Print("Starting ATSE Unit Tests (Atomic & Task Level)...");
    Print("==================================================");
    
    int passed = 0; int failed = 0;
    
    // 1. Atomic Pure-Logic Tests
    if (TestTickScraper::Run()) passed++; else failed++;
    if (TestPriceInverter::Run()) passed++; else failed++;
    if (TestLotStepAligner::Run()) passed++; else failed++;
    if (TestStopsGuard::Run()) passed++; else failed++;

    // 2. Integration & Manager Tests
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
    if (TestHistoryAnalyzer::Run()) passed++; else failed++;
    if (TestOrderValidator::Run()) passed++; else failed++;
    if (TestPriceRiskSubdivision::Run()) passed++; else failed++;
    if (TestSmartPVB::Run()) passed++; else failed++;
    
    Print("==================================================");
    PrintFormat("Test Run Complete. Suites Passed: %d, Suites Failed: %d", passed, failed);
    Print("==================================================");

    int resHandle = FileOpen("AGS\\scenario_result.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
    if(resHandle != INVALID_HANDLE) {
        FileWriteString(resHandle, "id=UNIT_TEST_SUITE\r\n");
        FileWriteString(resHandle, StringFormat("passed=%d\r\n", passed));
        FileWriteString(resHandle, StringFormat("failed=%d\r\n", failed));
        FileWriteString(resHandle, StringFormat("status=%s\r\n", (failed == 0) ? "PASSED" : "FAILED"));
        FileClose(resHandle);
    }
    
    ExpertRemove();
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Print("ATSE Unit Tests EA Unloaded."); }
void OnTick() {}
