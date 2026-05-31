//+------------------------------------------------------------------+
//|                                         AGSConnectivityTest.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//|                    Connectivity & DB I/O Test Runner            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/google-gemini/gemini-cli"
#property version   "1.05"
#property strict

#include "UnitTests\TestDbIo.mqh"

int OnInit() {
    Print("Starting AGS Live Environment Unit Test (DB I/O)...");
    
    // Give time for terminal to sync in live mode
    for(int i=0; i<15; i++) {
        if(TerminalInfoInteger(TERMINAL_CONNECTED)) break;
        PrintFormat("  Waiting for connection... (%d/15)", i+1);
        Sleep(1000);
    }

    bool success = TestDbIo::Run();
    
    int resHandle = FileOpen("AGS\\scenario_result.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
    if(resHandle != INVALID_HANDLE) {
        FileWriteString(resHandle, "id=LIVE_DB_IO\r\n");
        FileWriteString(resHandle, StringFormat("status=%s\r\n", success ? "PASSED" : "FAILED"));
        FileClose(resHandle);
    }
    
    // In live mode, ExpertRemove is the standard way to stop.
    ExpertRemove();
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
