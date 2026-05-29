//+------------------------------------------------------------------+
//|                                           AGSScenarioRunner.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
// [v2.0] TSDL-based Deterministic E2E Test Runner for AGS          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/google-gemini/gemini-cli"
#property version   "2.20"
#property strict

//--- Include test engine & mocks
#include "Scenarios\CXTsdlParser.mqh"
#include "Scenarios\CXVirtualPricer.mqh"
#include "Mocks\MockPriceManager.mqh"
#include "Mocks\MockTerminalPlatform.mqh"
#include "Mocks\CXTestServiceFactory.mqh"

//--- Include core ATSE files
#include "..\Service\App\CXAppService.mqh"
#include "..\Core\Models\CXConfig.mqh"
#include "..\Core\DB\CXDatabase.mqh"
#include "..\Core\DB\CXSignalRepository.mqh"
#include "..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\Core\Guard\CXIntegrityGuard.mqh"

//--- [Inputs]
input string InpScenarioFile  = "AGS\\test_advanced_exit.tsd"; // TSDL Filename (MQL5/Files)
input string InpDatabaseName  = "AGS.db";                 // Target Database (Isolated)
input bool   InpUseCommonPath = true;                          // DB Path
input int    InpMaxTicks      = 100;                           // Safety Break

//--- Global Instances
CXTsdlScenario*        g_scenario = NULL;
CXVirtualPricer*      g_pricer = NULL;
MockPriceManager*     g_mockPriceMgr = NULL; 
MockTerminalPlatform* g_mockTerminal = NULL; 
CXTestServiceFactory* g_factory = NULL;      
CXAppService*         g_app = NULL;          
CXConfig*             g_config = NULL;       
ICXContext*           g_ctx = NULL;          
IRepository*          g_repo = NULL;         

CArrayObj*            g_traces = NULL;       
int                   g_currentTick = 0;
int                   g_maxTick = 0;
int                   g_passed = 0;
int                   g_failed = 0;
string                g_lastYymmddhh = "";  // [v2.3] INJECT 시 사용된 yymmddhh 추적

//--- Helper functions for state names mapping
int SessionStateNameToEnum(string name) {
    StringTrimLeft(name); StringTrimRight(name);
    if(name == "SESSION_READY" || name == "ORD_READY") return 0;
    if(name == "SESSION_EXECUTING" || name == "ORD_EXECUTING") return 2;
    if(name == "SESSION_TRAILING_ENTRY" || name == "ORD_TRACKING" || name == "ORD_TRAILING") return 5;
    if(name == "SESSION_ACTIVE" || name == "POS_MONITORING" || name == "POS_ACTIVE") return 10;
    if(name == "SESSION_CLOSED" || name == "SYS_CLOSED" || name == "SYS_DONE") return 30;
    if(name == "SESSION_ERROR" || name == "SYS_ERROR") return 99;
    return -1;
}

string SessionStateEnumToName(int state) {
    switch(state) {
        case 0:  return "ORD_READY";
        case 5:  return "ORD_TRACKING";
        case 10: return "POS_MONITORING";
        case 30: return "SYS_CLOSED";
        case 99: return "SYS_ERROR";
        default: return "UNKNOWN_" + IntegerToString(state);
    }
}

string XeStatusEnumToName(int status) {
    switch(status) {
        case 0:  return "XE_READY";
        case 5:  return "XE_PENDING_PLACED";
        case 10: return "XE_EXECUTED";
        case 20: return "XE_CLOSED_SIGNAL";
        case 99: return "XE_ERROR";
        default: return "UNKNOWN_" + IntegerToString(status);
    }
}

//--- Trace Log Entry class definition
class CXTsdlTraceEntry : public CObject {
public:
    int    tick;
    string expState;
    int    actState;
    string expXe;
    int    actXe;
    bool   isPass;
    string failMsg;

    CXTsdlTraceEntry() : tick(0), expState(""), actState(-1), expXe(""), actXe(-1), isPass(false), failMsg("") {}
};

int OnInit() {
    string scenFile = InpScenarioFile;
    
    // 임시 타겟 파일 존재 시 읽어서 우선 적용 (배치 자동화용)
    if(FileIsExist("AGS\\scenario_target.txt", FILE_COMMON)) {
        int targetHandle = FileOpen("AGS\\scenario_target.txt", FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(targetHandle != INVALID_HANDLE) {
            string targetPath = FileReadString(targetHandle);
            StringReplace(targetPath, "\r", "");
            StringReplace(targetPath, "\n", "");
            StringTrimLeft(targetPath); StringTrimRight(targetPath);
            if(targetPath != "") {
                scenFile = targetPath;
                PrintFormat("[RUNNER] Redirecting target to: %s", scenFile);
            }
            FileClose(targetHandle);
        }
    }

    //--- [v2.2] Pre-Flight Environment Audit for Scenario TSDL file
    CXIntegrityGuard envGuard;
    if(!envGuard.AuditEnvironment(scenFile)) {
        Print("================================================");
        Print("[RUNNER-FATAL] Environmental Audit Failed!");
        Print(envGuard.GetDetailedReport());
        Print("================================================");
        return INIT_FAILED;
    }

    g_scenario = CXTsdlParser::Parse(scenFile);
    if(IS_INVALID(g_scenario)) {
        PrintFormat("[RUNNER] ERROR: Scenario file '%s' not found.", scenFile);
        return INIT_FAILED;
    }

    g_traces = new CArrayObj();
    g_pricer = new CXVirtualPricer("GOLDF#", 0.01);
    g_pricer.InitModel(g_scenario.m_pricerModel, 2350.00, 2);

    g_mockPriceMgr = new MockPriceManager(NULL);
    g_mockPriceMgr.SetPricer(g_pricer);
    g_mockTerminal = new MockTerminalPlatform();
    g_factory = new CXTestServiceFactory(g_mockPriceMgr, g_mockTerminal);
    
    g_config = new CXConfig("1001", 0.5, "127.0.0.1", false, false, "*", LOG_LVL_TRACE, true, false, true, true, false, true, true, false, false, true, InpDatabaseName, InpUseCommonPath);
    g_app = new CXAppService();
    if(!g_app.Initialize(g_config, g_factory)) return INIT_FAILED;

    g_ctx = g_app.GetContext();
    g_repo = CX_GET_OBJ(g_ctx, "repo", IRepository);
    
    // Clean up from previous run if any
    if(IS_VALID(g_repo)) {
        g_repo.DeleteBySid(g_scenario.GetDefine("SID"));
    }

    g_maxTick = g_scenario.GetMaxTick();
    if(g_maxTick <= 0) g_maxTick = InpMaxTicks;
    
    Print("==================================================");
    PrintFormat("TSDL Runner Started: %s", g_scenario.m_desc);
    Print("==================================================");

    EventSetMillisecondTimer(100);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    EventKillTimer();
    
    Print("==================================================");
    PrintFormat("TSDL Runner Finished. Total Ticks: %d, Passed: %d, Failed: %d", g_currentTick, g_passed, g_failed);
    Print("==================================================");

    // [v2.0 Batch Automation] 결과를 결과 파일에 기록하여 파워쉘이 집계할 수 있도록 지원 (FILE_COMMON)
    int resHandle = FileOpen("AGS\\scenario_result.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
    if(resHandle != INVALID_HANDLE) {
        if(g_scenario != NULL) {
            FileWriteString(resHandle, StringFormat("id=%s\r\n", g_scenario.m_id));
            FileWriteString(resHandle, StringFormat("ticks=%d\r\n", g_currentTick));
            FileWriteString(resHandle, StringFormat("passed=%d\r\n", g_passed));
            FileWriteString(resHandle, StringFormat("failed=%d\r\n", g_failed));
            FileWriteString(resHandle, StringFormat("status=%s\r\n", (g_failed == 0 && g_passed > 0) ? "PASSED" : "FAILED"));
        } else {
            FileWriteString(resHandle, "status=FAILED\r\nerror=Scenario not loaded\r\n");
        }
        FileClose(resHandle);
    }

    // [v2.2 Fix] Ownership & Double Free Protection
    // g_app owns config, repo, db, priceManager(mockPriceMgr), terminalPlatform(mockTerminal)
    SAFE_DELETE(g_app);
    SAFE_DELETE(g_factory);
    SAFE_DELETE(g_pricer);
    SAFE_DELETE(g_scenario);
    SAFE_DELETE(g_traces);
}

void HandleAction(CXTsdlAction* action) {
    if(IS_INVALID(action)) return;

    if(action.m_type == "MARKET") {
        if(action.m_target == "price") {
            g_pricer.OverridePrice(action.GetParamDouble("price"));
        }
    }
    else if(action.m_type == "INJECT") {
        if(action.m_target == "terminal") {
            string sym = action.GetParam("symbol"); if(sym == "") sym = "GOLDF#";
            g_mockTerminal.InjectMockAsset(action.GetParamBool("order_fill"),
                                           (ulong)action.GetParamInt("ticket"),
                                           action.GetParam("sid"),
                                           sym,
                                           action.GetParamInt("magic", 1001),
                                           action.GetParamInt("dir", 1),
                                           action.GetParamDouble("lot", 0.1),
                                           action.GetParamDouble("price"),
                                           action.GetParamDouble("sl"),
                                           action.GetParamDouble("tp"));
        }
        else if(action.m_target == "signals") {
            CXSignal* sig = new CXSignal();
            
            // [v2.1] Auto-Assemble SID from components if missing
            string sid = action.GetParam("sid");
            string yymmddhh_action = action.GetParam("yymmddhh");
            if(yymmddhh_action != "") g_lastYymmddhh = yymmddhh_action;  // [v2.3] 추적
            if(sid == "" && action.GetParamInt("cno") > 0) {
                sid = StringFormat("%04d-%s-%02d-%02d-%d-%d", 
                                   action.GetParamInt("cno"), action.GetParam("yymmddhh"),
                                   action.GetParamInt("sno"), action.GetParamInt("gno"),
                                   action.GetParamInt("dir", 1), action.GetParamInt("type", 0));
            }
            sig.SetSid(sid);
            
            sig.SetCno(action.GetParamInt("cno"));
            sig.SetSno(action.GetParamInt("sno"));
            string sym = action.GetParam("symbol"); if(sym == "") sym = "GOLDF#";
            sig.SetSymbol(sym);
            sig.SetDir(action.GetParamInt("dir", 1));
            sig.SetType(action.GetParamInt("type", 0));
            sig.SetLot(action.GetParamDouble("lot", 0.1));
            sig.SetXAEntry(action.GetParamInt("xa_entry", 1));
            sig.SetXAExit(action.GetParamInt("xa_exit", 0));
            sig.SetStatus(action.GetParamInt("xe_status", 0));
            sig.SetMagic(action.GetParamInt("magic", 1001));
            sig.SetPriceSignal(action.GetParamDouble("price_signal"));
            sig.SetTEStart(action.GetParamDouble("te_start"));
            sig.SetTEStep(action.GetParamDouble("te_step"));
            sig.SetTELimit(action.GetParamDouble("te_limit"));
            sig.SetTEInterval(action.GetParamInt("te_interval"));
            sig.SetSL(action.GetParamDouble("sl"));
            sig.SetTP(action.GetParamDouble("tp"));
            sig.SetTSStart(action.GetParamInt("ts_start"));
            sig.SetTSStep(action.GetParamInt("ts_step"));
            if(IS_VALID(g_repo)) g_repo.SaveSignal(sig);
            SAFE_DELETE(sig);
        }
    }
    else if(action.m_type == "FAIL") {
        if(action.m_target == "broker") {
            g_mockTerminal.SetFailNextTrade(action.GetParamBool("next"));
        }
    }
}

void VerifyExpectation(CXTsdlExpect* expect, int tick) {
    if(IS_INVALID(expect)) return;

    bool passed = true;
    string failDetails = "";

    if(expect.m_type == "session") {
        string sid = expect.GetParam("sid");
        if(sid == "") sid = g_scenario.GetDefine("SID");
        
        // [v2.1] Auto-Assemble SID from components if still missing
        if(sid == "") {
            string cnoStr = g_scenario.GetDefine("CNO");
            long cnoVal = StringToInteger(cnoStr);
            PrintFormat("[SID-DEBUG] CNO='%s'(%d), g_lastYymmddhh='%s', SNO='%s', GNO='%s', DIR='%s', TYPE='%s'",
                cnoStr, (int)cnoVal,
                g_lastYymmddhh,
                g_scenario.GetDefine("SNO"), g_scenario.GetDefine("GNO"),
                g_scenario.GetDefine("DIR"), g_scenario.GetDefine("TYPE"));
            if(cnoVal > 0) {
                // [v2.3] g_lastYymmddhh 우선, 없으면 DEFINE, 없으면 "26052804" fallback
                string yymmddhh = g_lastYymmddhh;
                if(yymmddhh == "") yymmddhh = g_scenario.GetDefine("YYMMDDHH");
                if(yymmddhh == "") yymmddhh = "26052804";
                
                sid = StringFormat("%04d-%s-%02d-%02d-%d-%d", 
                                   (int)cnoVal, yymmddhh,
                                   (int)StringToInteger(g_scenario.GetDefine("SNO")), (int)StringToInteger(g_scenario.GetDefine("GNO")),
                                   (int)StringToInteger(g_scenario.GetDefine("DIR")), (int)StringToInteger(g_scenario.GetDefine("TYPE")));
            }
        }
        
        ICXSignal* sig = (IS_VALID(g_repo)) ? g_repo.GetSignalBySid(sid) : NULL;
        
        if(IS_INVALID(sig)) {
            passed = false;
            failDetails = "Signal SID:" + sid + " not found in DB.";
        } else {
            // Check xe_status
            string expXe = expect.GetParam("xe_status");
            if(expXe != "") {
                int actXe = sig.GetStatus();
                // Map names like XE_EXECUTED (10) to values
                int expXeVal = -1;
                if(expXe == "XE_READY") expXeVal = 0;
                else if(expXe == "XE_EXECUTED") expXeVal = 10;
                else if(expXe == "XE_CLOSED_SIGNAL") expXeVal = 20;
                else if(expXe == "XE_ERROR") expXeVal = 99;
                else if(expXe == "XE_PENDING_PLACED") expXeVal = 5;
                else expXeVal = (int)StringToInteger(expXe);

                if(actXe != expXeVal) {
                    passed = false;
                    failDetails += StringFormat("xe_status Mismatch: Exp:%s(%d), Act:%d. ", expXe, expXeVal, actXe);
                }
            }
            
            // Check xa_exit
            string expXaEx = expect.GetParam("xa_exit");
            if(expXaEx != "") {
                int actXaEx = sig.GetXAExit();
                if(actXaEx != (int)StringToInteger(expXaEx)) {
                    passed = false;
                    failDetails += StringFormat("xa_exit Mismatch: Exp:%s, Act:%d. ", expXaEx, actXaEx);
                }
            }
        }
        SAFE_DELETE(sig);
    }
    else if(expect.m_type == "terminal") {
        ulong ticket = (ulong)expect.GetParamInt("ticket");
        bool exists = expect.GetParamBool("exists");
        // Default to true if not specified
        if(expect.GetParam("exists") == "") exists = true;
        
        bool actExists = g_mockTerminal.IsPositionExists(ticket) || g_mockTerminal.IsOrderExists(ticket);
        
        if(actExists != exists) {
            passed = false;
            failDetails = StringFormat("Terminal Asset Ticket:%I64u Exists: Exp:%s, Act:%s", ticket, exists?"True":"False", actExists?"True":"False");
        }
        
        string expSLStr = expect.GetParam("sl");
        if(expSLStr != "") {
            double expSL = StringToDouble(expSLStr);
            double actSL = (g_mockTerminal.IsPositionExists(ticket)) ? g_mockTerminal.GetPositionSL(ticket) : g_mockTerminal.GetOrderSL(ticket);
            if(MathAbs(actSL - expSL) > 0.00001) {
                passed = false;
                failDetails += StringFormat("SL Mismatch: Exp:%.5f, Act:%.5f", expSL, actSL);
            }
        }
    }

    if(passed) {
        g_passed++;
        PrintFormat("[TICK:%d] PASS: %s", tick, expect.m_type);
    } else {
        g_failed++;
        PrintFormat("[TICK:%d] FAIL: %s -> %s %s", tick, expect.m_type, expect.m_failMsg, failDetails);
    }
}

void ExecuteTick(int tick) {
    CXTsdlStep* step = g_scenario.GetStep(tick);
    
    // 1. Apply Actions
    if(IS_VALID(step)) {
        for(int i = 0; i < step.m_actions.Total(); i++) {
            HandleAction(CX_CAST(CXTsdlAction, step.m_actions.At(i)));
        }
    }

    // 2. Update Virtual World
    g_pricer.GenerateNextPrice();
    g_mockTerminal.UpdateBrokerTriggeredExits("GOLDF#", g_pricer.GetBid(), g_pricer.GetAsk());

    // 3. App Heartbeat
    g_app.Pulse(EVENT_TIMER);
    
    // 4. Verify Expectations
    if(IS_VALID(step)) {
        for(int i = 0; i < step.m_expectations.Total(); i++) {
            VerifyExpectation(CX_CAST(CXTsdlExpect, step.m_expectations.At(i)), tick);
        }
    }
}

void OnTimer() {
    g_currentTick++;
    if(g_currentTick > g_maxTick) { ExpertRemove(); return; }
    ExecuteTick(g_currentTick);
}
