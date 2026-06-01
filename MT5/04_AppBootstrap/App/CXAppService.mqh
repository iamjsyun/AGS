#ifndef CXAPPSERVICE_MQH
#define CXAPPSERVICE_MQH

#include "..\..\01_Core\Interfaces\ICXAppService.mqh"
#include "..\..\01_Core\Interfaces\ICXConfig.mqh"
#include "..\..\01_Core\Interfaces\IDatabase.mqh"
#include "..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\01_Core\Interfaces\ICXServiceFactory.mqh"
#include "..\..\01_Core\Interfaces\ICXSignalWatcher.mqh"
#include "..\..\03_Platform\Session\CXAssetManager.mqh"
#include "..\..\06_Orchestration\Workflow\AppOrchestrator.mqh"
#include "..\..\03_Platform\Watcher\CXSignalWatcher.mqh"
#include "..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\05_Guard\CXGuard.mqh"
#include "..\..\06_Orchestration\Sequence\CXSequenceOrchestrator.mqh"
#include "..\..\01_Core\Interfaces\IXGuard.mqh"
#include "..\..\06_Orchestration\Workflow\CXStageFactory.mqh"
#include "..\..\06_Orchestration\Workflow\CXTaskFactory.mqh"
#include "..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\01_Core\Logger\CXMessageProvider.mqh"
#include "..\..\01_Core\Logger\CXLogDispatcher.mqh"
#include "CXServiceFactory.mqh"
#include "..\..\02_Domain\Models\CXConfig.mqh"
#include "..\..\05_Guard\CXIntegrityGuard.mqh"
#include "..\..\01_Core\Interfaces\IXOrderManager.mqh"
#include "..\..\01_Core\Interfaces\IXPositionManager.mqh"

#include "..\..\01_Core\UI\CXUI.mqh"

/**
 * @class CXAppService
 * @brief Service that oversees the entire lifecycle of the EA and dependency injection (v14.47 Dynamic Asset)
 */
class CXAppService : public ICXAppService {
private:
    ICXConfig*            m_config;
    IDatabase*            m_db;
    IRepository*          m_repo;
    ICXAssetManager*      m_assetManager;
    ICXServiceFactory*    m_factory;
    ICXSignalWatcher*     m_watcher;
    ICXLogger*            m_logger;
    ICXContext*           m_globalContext;
    ICXParam*             m_pulseParam;
    
    // Lifecycle-managed dependencies
    CXSequenceOrchestrator* m_orchestrator;
    IXGuard*              m_guard;
    IXTerminalPlatform*   m_terminalPlatform;
    ICXPriceManager*      m_priceManager;
    ICXSymbolManager*     m_symbolManager;
    ICXRiskManager*       m_riskManager;
    IXExitManager*        m_exitManager;
    IXOrderManager*       m_orderManager;
    IXPositionManager*    m_positionManager;
    CXUI*                 m_ui;
    ICXIntegrityGuard*    m_integrityGuard; // [v2.1] Independent Inspector

    // Scheduler tick counters (v1.0 Multi-Interval Scheduler)
    uint                  m_lastWatcherScanTime;
    uint                  m_lastAssetPulseTime;
    uint                  m_lastUiRefreshTime;

public:
    CXAppService() : m_config(NULL), m_db(NULL), m_repo(NULL), m_assetManager(NULL), 
                    m_factory(NULL), m_watcher(NULL), m_logger(NULL), m_globalContext(NULL),
                    m_orchestrator(NULL), m_guard(NULL), m_terminalPlatform(NULL),
                    m_priceManager(NULL), m_symbolManager(NULL), m_riskManager(NULL),
                    m_exitManager(NULL), m_orderManager(NULL), m_positionManager(NULL),
                    m_ui(NULL), m_integrityGuard(NULL),
                    m_lastWatcherScanTime(0), m_lastAssetPulseTime(0), m_lastUiRefreshTime(0) {}

    virtual ~CXAppService() override {
        SAFE_DELETE(m_ui);
        SAFE_DELETE(m_integrityGuard);
        SAFE_DELETE(m_watcher);
        SAFE_DELETE(m_pulseParam);
        // [v2.2 Fix] Explicitly delete here because exit_mgr is registered with managed=false to prevent context ownership
        // Workaround for issue where CXContext is not deleted properly due to CHashMap<string,CObject*>::CopyTo limitations
        SAFE_DELETE(m_exitManager);
        SAFE_DELETE(m_orderManager);
        SAFE_DELETE(m_positionManager);
        SAFE_DELETE(m_factory);
        SAFE_DELETE(m_globalContext);
    }

    virtual bool Initialize(ICXConfig* config, ICXServiceFactory* factory) override {
        m_config = config;
        m_factory = factory;
        if(IS_INVALID(m_config) || IS_INVALID(m_factory)) return false;

        m_globalContext = m_factory.CreateContext();
        if(IS_INVALID(m_globalContext)) return false;

        // [v1.4 Assembly Pattern] Delegate all core service registration to the factory
        if(!m_factory.AssembleKernel(m_globalContext, m_config)) return false;

        // Retrieve assembled services for local member access
        m_logger           = m_globalContext.GetLogger();
        m_orchestrator     = CX_GET_OBJ(m_globalContext, "orchestrator", CXSequenceOrchestrator);
        m_db               = CX_GET_OBJ(m_globalContext, "db", IDatabase);
        m_repo             = CX_GET_OBJ(m_globalContext, "repo", IRepository);
        m_assetManager     = CX_GET_OBJ(m_globalContext, "asset_mgr", ICXAssetManager);
        m_exitManager      = CX_GET_OBJ(m_globalContext, "exit_mgr", IXExitManager);
        m_orderManager     = CX_GET_OBJ(m_globalContext, "order_mgr", IXOrderManager);
        m_positionManager  = CX_GET_OBJ(m_globalContext, "pos_mgr", IXPositionManager);

        m_pulseParam = new CXParam();

        // Initialize UI and Integrity Guard
        m_ui = new CXUI(m_globalContext);
        if(IS_VALID(m_ui)) m_ui.Initialize();

        m_integrityGuard = new CXIntegrityGuard();
        if(!m_integrityGuard.Inspect(m_globalContext, m_orchestrator)) {
            if(IS_VALID(m_logger)) {
                m_logger.Log(LOG_LVL_ERROR, "[BOOTSTRAP-FATAL] Assembly Integrity Check Failed.");
                m_logger.Log(LOG_LVL_ERROR, m_integrityGuard.GetDetailedReport());
            }
            return false;
        }

        // [v18.42] Finalize startup
        m_watcher = new CXSignalWatcher(m_repo, m_config, m_assetManager, m_globalContext, m_factory, "Unified");
        if(IS_INVALID(m_watcher) || !m_watcher.Bind()) return false;

        if(IS_VALID(m_logger)) m_logger.Log(LOG_LVL_INFO, "[BOOTSTRAP] System Modernization v1.4 Assembly Complete. System Ready.");
        return true;
    }

    void AppServiceDebugLog(string msg) {
        int h = FileOpen("debug_log.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
        if(h != INVALID_HANDLE) {
            FileSeek(h, 0, SEEK_END);
            FileWriteString(h, msg + "\r\n");
            FileClose(h);
        }
    }

    virtual void Pulse(ENUM_CX_EVENT event = EVENT_TIMER) override {
        if(IS_INVALID(m_pulseParam)) return;
        
        uint currentTick = GetTickCount();
        
        // 1. OnTick High-Performance Path
        if(event == EVENT_TICK) {
            m_pulseParam.Reset();
            m_pulseParam.SetEvent(EVENT_TICK);
            m_pulseParam.SetContext(m_globalContext);
            if(IS_VALID(m_assetManager)) m_assetManager.Pulse(m_pulseParam);
            return;
        }
        
        // [v1.0 Test Mode Bypass] E2E scenario testing uses 0.5s virtual interval
        bool isTest = (IS_VALID(m_config) && m_config.GetTimerInterval() < 1.0);
        
        // 2. OnTimer Heartbeat Path
        // A. Watcher Scan (400ms)
        if(isTest || currentTick - m_lastWatcherScanTime >= 400) {
            AppServiceDebugLog("  AppService::Pulse - Watcher Scan Begin");
            m_pulseParam.Reset();
            m_pulseParam.SetEvent(EVENT_TIMER);
            if(IS_VALID(m_watcher)) m_watcher.Pulse(m_pulseParam);
            AppServiceDebugLog("  AppService::Pulse - Watcher Scan End");
            m_lastWatcherScanTime = currentTick;
        }
        
        // B. Core Pulse (300ms)
        if(isTest || currentTick - m_lastAssetPulseTime >= 300) {
            AppServiceDebugLog("  AppService::Pulse - Core Pulse Begin");
            m_pulseParam.Reset();
            m_pulseParam.SetEvent(EVENT_TIMER);
            m_pulseParam.SetContext(m_globalContext);
            if(IS_VALID(m_assetManager)) m_assetManager.Pulse(m_pulseParam);
            AppServiceDebugLog("  AppService::Pulse - Core Pulse End");
            m_lastAssetPulseTime = currentTick;
        }

        // C. UI Refresh (500ms)
        if(isTest || currentTick - m_lastUiRefreshTime >= 500) {
            AppServiceDebugLog("  AppService::Pulse - UI Refresh Begin");
            if(IS_VALID(m_ui)) m_ui.Refresh();
            AppServiceDebugLog("  AppService::Pulse - UI Refresh End");
            m_lastUiRefreshTime = currentTick;
        }
    }

    virtual ICXContext* GetContext() override { return m_globalContext; }

    virtual void OnTradeTransaction(const MqlTradeTransaction& trans,
                                    const MqlTradeRequest& request,
                                    const MqlTradeResult& result) override {
        if(IS_INVALID(m_pulseParam)) return;
        m_pulseParam.Reset();
        m_pulseParam.SetEvent(EVENT_TRANSACTION);
        m_pulseParam.SetTransaction(trans); 
        m_pulseParam.SetContext(m_globalContext); // [v18.43 Fix]
        
        if(IS_VALID(m_assetManager)) m_assetManager.Pulse(m_pulseParam);
    }
};

#endif
