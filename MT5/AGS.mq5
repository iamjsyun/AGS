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
#include "Service\App\CXAppService.mqh"
#include "Service\App\CXServiceFactory.mqh"
#include "Core\Models\CXConfig.mqh"
#include "Core\Guard\TestDependencyInjection.mqh"

//--- [Group: Basic Configuration]
input string         InpTargetMagics    = "1001,1002,3001,3002"; // Target Magic Numbers (CSV)
input int            InpTimerInterval   =  200;                 // Timer Interval (Seconds)
input string         InpRemoteAddr      = "127.0.0.1:878";     // Remote Log Address (IP:Port)
input string         InpDatabaseName    = "ATS.db";            // DB: Database Filename
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
 
    // 1. Configuration 객체 생성 (v10.27)
    g_config = new CXConfig(InpTargetMagics, InpTimerInterval, InpRemoteAddr, InpDatabaseName, InpUseCommonPath);
    
    if(IS_INVALID(g_config)) return INIT_FAILED;

    // 2. 앱 서비스 초기화 및 기동
    CXServiceFactory* factory = new CXServiceFactory();
    g_app = new CXAppService();
    if(IS_INVALID(g_app) || !g_app.Initialize(g_config, factory)) {
        Print("App Service initialization failed.");
        return INIT_FAILED;
    }

    // 3. 의존성 주입(DI) 정합성 검증 테스트 가동 (Fail-Fast)
    if(!TestDependencyInjection::Verify(g_app.GetContext())) {
        Print("Dependency Injection Verification failed. Self-Terminating EA.");
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
