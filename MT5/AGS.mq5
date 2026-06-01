//+------------------------------------------------------------------+
//|                                                          AGS.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//| [v13.6] Main AGS Engine - Consolidated Integrity Standard        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/google-gemini/gemini-cli"
#property version   "13.6"
#property strict

//--- Include core service
#include "04_AppBootstrap\App\CXAppService.mqh"
#include "04_AppBootstrap\App\CXServiceFactory.mqh"
#include "02_Domain\Models\CXConfig.mqh"
#include "01_Core\App\ea_manager.mqh"

//--- [Group: Basic Configuration]
input string         InpTargetMagics    = "1001,1002,3001,3002"; // Target Magic Numbers (CSV)
input int            InpTimerInterval   =  200;                 // Timer Interval (Seconds)
input string         InpRemoteAddr      = "127.0.0.1:878";     // Remote Log Address (IP:Port)
input string         InpDatabaseName    = "AGS.db";            // DB: Database Filename
input bool           InpUseCommonPath   = true;                // DB: Use Terminal Common Path

//--- Global Instance
CXAppService* g_app = NULL;
CXConfig*     g_config = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Chart GUI Clean-up
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);
    
    //--- [v10.4] Testing Mode: Timer-only execution (100ms / 0.1s)
    EventSetMillisecondTimer(InpTimerInterval);
    
    //--- [v2.2] Pre-Flight Environment Audit
    CXIntegrityGuard envGuard;
    if(!envGuard.AuditEnvironment(InpDatabaseName)) {
        Print("================================================");
        Print("[BOOTSTRAP-FATAL] Environmental Audit Failed!");
        Print(envGuard.GetDetailedReport());
        Print("================================================");
        return INIT_FAILED;
    }
 
    // 1. Configuration object creation
    g_config = new CXConfig(InpTargetMagics, InpTimerInterval, InpRemoteAddr, InpDatabaseName, InpUseCommonPath);
    if(IS_INVALID(g_config)) return INIT_FAILED;

    // 2. Service initialization and Startup (Integrity Check is internal)
    CXServiceFactory* factory = new CXServiceFactory();
    g_app = new CXAppService();
    if(IS_INVALID(g_app) || !g_app.Initialize(g_config, factory)) {
        Print("[BOOTSTRAP-FATAL] App Service initialization failed.");
        return INIT_FAILED;
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    SAFE_DELETE(g_app);
    SAFE_DELETE(g_config);
    ObjectsDeleteAll(0, "ATSE_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() { if(IS_VALID(g_app)) g_app.Pulse(EVENT_TICK); }

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
    CheckEaCommand();
    if(IS_VALID(g_app)) g_app.Pulse();
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
    if(IS_VALID(g_app)) g_app.OnTradeTransaction(trans, request, result);
}
