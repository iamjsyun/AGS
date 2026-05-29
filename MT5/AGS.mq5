//+------------------------------------------------------------------+
//|                                                          ATS.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//| [v13.5] Main ATS Engine - UAF & Resilience Standard              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/google-gemini/gemini-cli"
#property version   "10.27"
#property strict

//--- Include core service
#include "App\CXAppService.mqh"
#include "App\Infra\CXServiceFactory.mqh"
#include "Platform\Core\Models\CXConfig.mqh"

//--- [Group: Basic Configuration]
input string         InpTargetMagics    = "1001,1002,3001,3002"; // Target Magic Numbers (CSV)
input double         InpTimerInterval   = 0.2;                 // Timer Interval (Seconds)
input string         InpRemoteAddr      = "127.0.0.1:878";     // Remote Log Address (IP:Port)
input string         InpDatabaseName    = "ATS.db";            // DB: Database Filename
input bool           InpUseCommonPath   = true;                // DB: Use Terminal Common Path

//--- [Group: Global Log Options]
input bool           InpLog_UseUI       = true;                // UI: Dashboard Log Enabled
input bool           InpLog_UseRemote   = true;                // Remote: Global Remote Toggle
input string         InpLog_FilterCnos  = "*";                 // Filter: Target CNO List (CSV / *:All)
input ENUM_LOG_LEVEL InpLog_Level       = LOG_LVL_TRACE;        // Log Level

//--- [Group: Signal Watcher Log]
input bool           InpWatcher_UseFile   = true;              // Watcher: File Log Enabled
input bool           InpWatcher_UseRemote = true;              // Watcher: Remote Log Enabled
input bool           InpWatcher_InitStart = true;              // Watcher: Clear Log on Start (Mandatory by v11.5)

//--- [Group: System Infra Log]
input bool           InpSystem_UseFile    = true;              // System: File Log Enabled
input bool           InpSystem_UseRemote  = false;             // System: Remote Log Enabled
input bool           InpSystem_InitStart  = true;              // System: Clear Log on Start (Mandatory by v11.5)

//--- [Group: Trading Session Log]
input bool           InpSession_UseFile   = true;              // Session: File Log Enabled
input bool           InpSession_UseRemote = true;              // Session: Remote Log Enabled
input bool           InpSession_UseUI     = true;              // Session: UI Log Enabled
input bool           InpSession_InitStart = true;              // Session: Clear Log on Start (Mandatory by v11.5)

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
    EventSetMillisecondTimer(100);
    
 
    // 1. Configuration 객체 생성 (v10.27)
    g_config = new CXConfig(InpTargetMagics, InpTimerInterval, InpRemoteAddr, 
                            InpLog_UseUI, InpLog_UseRemote, InpLog_FilterCnos, InpLog_Level,
                            InpWatcher_UseFile, InpWatcher_UseRemote, InpWatcher_InitStart,
                            InpSystem_UseFile, InpSystem_UseRemote, InpSystem_InitStart,
                            InpSession_UseFile, InpSession_UseRemote, InpSession_UseUI, InpSession_InitStart,
                            InpDatabaseName, InpUseCommonPath);
    
    if(IS_INVALID(g_config)) return INIT_FAILED;

    // 2. 앱 서비스 초기화 및 기동
    CXServiceFactory* factory = new CXServiceFactory();
    g_app = new CXAppService();
    if(IS_INVALID(g_app) || !g_app.Initialize(g_config, factory)) {
        Print("App Service initialization failed.");
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
void OnTick() {
    if(IS_VALID(g_app)) g_app.Pulse(EVENT_TICK);
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
    if(IS_VALID(g_app)) g_app.Pulse();
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
    //-- 트랜잭션 이벤트는 시스템 정합성을 위해 유지
    if(IS_VALID(g_app)) g_app.OnTradeTransaction(trans, request, result);
}
