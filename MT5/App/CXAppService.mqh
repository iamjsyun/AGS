#ifndef CXAPPSERVICE_MQH
#define CXAPPSERVICE_MQH

#include "..\Platform\Core\Interfaces\ICXAppService.mqh"
#include "..\Platform\Core\Interfaces\ICXConfig.mqh"
#include "..\Platform\Core\Interfaces\IDatabase.mqh"
#include "..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\Platform\Core\Interfaces\ICXServiceFactory.mqh"
#include "..\Platform\Core\Interfaces\ICXSignalWatcher.mqh"
#include "..\Session\CXAssetManager.mqh"
#include "Orchestration\AppOrchestrator.mqh"
#include "..\Watcher\CXSignalWatcher.mqh"
#include "..\Platform\Core\Models\CXParam.mqh"
#include "..\Platform\Shared\Guard\CXGuard.mqh"
#include "..\Platform\Core\Sequence\CXSequenceOrchestrator.mqh"
#include "..\Platform\Core\Interfaces\IXGuard.mqh"
#include "Orchestration\CXStageFactory.mqh"
#include "Orchestration\CXTaskFactory.mqh"
#include "..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\Platform\Shared\Logging\CXLogDispatcher.mqh"
#include "Infra\CXServiceFactory.mqh"
#include "..\Platform\Core\Models\CXConfig.mqh"

#include "..\Platform\UI\CXUI.mqh"

/**
 * @class CXAppService
 * @brief EA의 전체 생명주기 및 의존성 주입을 총괄하는 서비스 (v14.47 Dynamic Asset)
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
    IXExitManager*        m_exitManager;
    CXUI*                 m_ui;

    // Scheduler tick counters (v1.0 Multi-Interval Scheduler)
    uint                  m_lastWatcherScanTime;
    uint                  m_lastAssetPulseTime;
    uint                  m_lastUiRefreshTime;

public:
    CXAppService() : m_config(NULL), m_db(NULL), m_repo(NULL), m_assetManager(NULL), 
                    m_factory(NULL), m_watcher(NULL), m_logger(NULL), m_globalContext(NULL),
                    m_orchestrator(NULL), m_guard(NULL), m_terminalPlatform(NULL),
                    m_priceManager(NULL), m_exitManager(NULL), m_ui(NULL),
                    m_lastWatcherScanTime(0), m_lastAssetPulseTime(0), m_lastUiRefreshTime(0) {}

    virtual ~CXAppService() override {
        SAFE_DELETE(m_ui);
        SAFE_DELETE(m_watcher);
        SAFE_DELETE(m_assetManager);
        SAFE_DELETE(m_repo);
        SAFE_DELETE(m_db);
        SAFE_DELETE(m_config);
        SAFE_DELETE(m_globalContext);
        SAFE_DELETE(m_logger);
        SAFE_DELETE(m_orchestrator);
        SAFE_DELETE(m_guard);
        SAFE_DELETE(m_terminalPlatform);
        SAFE_DELETE(m_priceManager);
        SAFE_DELETE(m_exitManager);
        SAFE_DELETE(m_pulseParam);
    }

    virtual bool Initialize(ICXConfig* config, ICXServiceFactory* factory) override {
        m_config = config;
        m_factory = factory;
        if(IS_INVALID(m_config) || IS_INVALID(m_factory)) return false;

        m_globalContext = m_factory.CreateContext();
        if(IS_INVALID(m_globalContext)) return false;

        m_logger = m_factory.CreateLogger("System", m_config);
        
        // [v18.42] Log Bootstrap banner immediately to sync timestamps with Logger init (e.g. RemoteLog)
        if(IS_VALID(m_logger)) {
            m_logger.Log(LOG_LVL_INFO, "================================================");
            m_logger.Log(LOG_LVL_INFO, "[BOOTSTRAP] System Startup Initiated.");
            m_logger.Log(LOG_LVL_INFO, StringFormat("[BOOTSTRAP] Log Level: %s", EnumToString(m_config.GetLogLevel())));
            m_logger.Log(LOG_LVL_INFO, "[BOOTSTRAP] Log Initialization Mandate (v11.5) Applied.");
            m_logger.Log(LOG_LVL_INFO, "================================================");
        }

        m_orchestrator = new AppOrchestrator();
        m_guard = new CXGuard(m_globalContext);
        m_terminalPlatform = m_factory.CreateTerminalPlatform(m_globalContext);
        m_priceManager = m_factory.CreatePriceManager(m_globalContext);
        m_exitManager = m_factory.CreateExitManager(m_globalContext);
        m_pulseParam = new CXParam();

        m_globalContext.Register("logger", m_logger);
        m_globalContext.Register("global_logger", m_logger); // [v18.32] For cross-module system logging
        m_globalContext.Register("config", m_config);
        m_globalContext.Register("orchestrator", m_orchestrator);
        m_globalContext.Register("guard", m_guard);
        m_globalContext.Register("terminal_platform", m_terminalPlatform);
        m_globalContext.Register("price_mgr", m_priceManager);
        m_globalContext.Register("exit_mgr", m_exitManager);

        m_db = m_factory.CreateDatabase();
        if(IS_INVALID(m_db) || !m_db.Open(m_config.GetDatabaseName(), m_config.IsDatabaseCommon())) return false;
        
        // [v1.1] Link the database to the logger dispatcher
        CXLogDispatcher* dispatcher = dynamic_cast<CXLogDispatcher*>(m_logger);
        if(IS_VALID(dispatcher)) {
            dispatcher.SetDatabase(m_db);
        }
        
        m_repo = m_factory.CreateRepository(m_db);
        if(IS_INVALID(m_repo)) return false;
        m_globalContext.Register("db", m_db);
        m_globalContext.Register("repo", m_repo);

        m_assetManager = new CXAssetManager();
        m_assetManager.Initialize(m_repo, m_globalContext, m_factory);
        m_globalContext.Register("asset_mgr", m_assetManager);

        m_watcher = new CXSignalWatcher(m_repo, m_config, m_assetManager, m_globalContext, m_factory, "Unified");

        m_ui = new CXUI(m_globalContext);
        if(IS_VALID(m_ui)) m_ui.Initialize();
        
        return true;
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
        
        // 2. OnTimer Heartbeat Path
        // A. Watcher Scan (400ms)
        if(currentTick - m_lastWatcherScanTime >= 400) {
            m_pulseParam.Reset();
            m_pulseParam.SetEvent(EVENT_TIMER);
            if(IS_VALID(m_watcher)) m_watcher.Pulse(m_pulseParam);
            m_lastWatcherScanTime = currentTick;
        }
        
        // B. Core Pulse (300ms)
        if(currentTick - m_lastAssetPulseTime >= 300) {
            m_pulseParam.Reset();
            m_pulseParam.SetEvent(EVENT_TIMER);
            m_pulseParam.SetContext(m_globalContext);
            if(IS_VALID(m_assetManager)) m_assetManager.Pulse(m_pulseParam);
            m_lastAssetPulseTime = currentTick;
        }

        // C. UI Refresh (1000ms)
        if(currentTick - m_lastUiRefreshTime >= 500) {
            if(IS_VALID(m_ui)) m_ui.Refresh();
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
