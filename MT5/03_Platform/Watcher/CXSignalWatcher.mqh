#ifndef CXSIGNALWATCHER_MQH
#define CXSIGNALWATCHER_MQH

#include "..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\01_Core\Interfaces\ICXConfig.mqh"
#include "..\..\01_Core\Interfaces\ICXParam.mqh"
#include "..\..\01_Core\Interfaces\ICXFluentSequence.mqh"
#include "..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\01_Core\Interfaces\ICXServiceFactory.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\06_Orchestration\Sequence\CXSequenceOrchestrator.mqh"
#include "CXSignalDispatcher.mqh"

class CXSignalWatcher;

/**
 * @class CXWatcherSignalListener
 * @brief Helper class to delegate signal events to CXSignalWatcher (Workaround for lack of multiple inheritance)
 */
class CXWatcherSignalListener : public ICXSignalListener {
private:
    CXSignalWatcher* m_owner;
public:
    CXWatcherSignalListener(CXSignalWatcher* owner) : m_owner(owner) {}
    virtual void OnSignalDetected(ICXParam* xp) override;
};

/**
 * @class CXSignalWatcher
 * @brief Monitors DB signal tables and allocates them to appropriate asset sessions (Event-Driven support)
 */
class CXSignalWatcher : public ICXSignalWatcher {
private:
    IRepository*            m_repo;
    ICXConfig*              m_config;
    ICXAssetManager*        m_assetManager;
    ICXContext*             m_globalContext;
    ICXContext*             m_watcherContext;
    ICXLogger*              m_watcherLogger;
    ICXFluentSequence*      m_sequence;
    CXSequenceOrchestrator* m_orchestrator;
    CXSignalDispatcher*     m_dispatcher;
    CXWatcherSignalListener* m_listener;
    string                  m_mode;

public:
    CXSignalWatcher(IRepository* repo, ICXConfig* cfg, ICXAssetManager* pool, ICXContext* globalCtx, ICXServiceFactory* factory, string mode = "Entry") 
        : m_repo(repo), m_config(cfg), m_assetManager(pool), m_globalContext(globalCtx), m_mode(mode) {
        
        m_watcherLogger = factory.CreateLogger("Watcher_" + m_mode, cfg);

        m_watcherContext = factory.CreateContext();
        if(IS_VALID(m_watcherContext)) {
            m_watcherContext.Register("repo", repo);
            m_watcherContext.Register("config", cfg);
            m_watcherContext.Register("asset_mgr", pool);
            m_watcherContext.Register("orchestrator", globalCtx.Get("orchestrator"));
            m_watcherContext.Register("guard", globalCtx.Get("guard"));
            m_watcherContext.Register("exit_mgr", globalCtx.Get("exit_mgr"));
            m_watcherContext.Register("terminal_platform", globalCtx.Get("terminal_platform"));
            m_watcherContext.Register("db", globalCtx.Get("db"));
            m_watcherContext.Register("price_mgr", globalCtx.Get("price_mgr"));
            m_watcherContext.Register("sym_mgr", globalCtx.Get("sym_mgr"));
            m_watcherContext.Register("risk_mgr", globalCtx.Get("risk_mgr"));
            m_watcherContext.Register("logger", m_watcherLogger);
            m_watcherContext.Register("factory", factory);
        }

        m_dispatcher = new CXSignalDispatcher(repo);
        m_listener = new CXWatcherSignalListener(GetPointer(this));
        m_dispatcher.AddListener(m_listener);

        m_sequence = new CXFluentSequence(m_watcherContext, "Watcher" + m_mode + "Seq");
        m_orchestrator = CX_GET_OBJ(m_globalContext, "orchestrator", CXSequenceOrchestrator);
        
        if(IS_VALID(m_orchestrator) && IS_VALID(m_sequence)) {
            if(m_mode == "Exit") {
                m_orchestrator.BuildWatcherExitSequence(m_sequence);
            } else if(m_mode == "Unified") {
                m_orchestrator.BuildWatcherSequence(m_sequence);
            } else {
                m_orchestrator.BuildWatcherEntrySequence(m_sequence);
            }
            m_sequence.Build();
        }
    }

    virtual ~CXSignalWatcher() override {
        SAFE_DELETE(m_dispatcher);
        SAFE_DELETE(m_listener);
        SAFE_DELETE(m_sequence);
        SAFE_DELETE(m_watcherContext);
        SAFE_DELETE(m_watcherLogger);
    }

    void OnSignalDetected(ICXParam* xp) {
        // [v2.2] We no longer pulse the sequence per-signal. 
        // Instead, we let the Dispatcher finish scanning, and Pulse() will handle the sequence.
        // This avoids redundant LoadEntrySignals calls and prevents logger redirection issues.
    }

    virtual bool Bind() override {
        return (IS_VALID(m_sequence)) ? m_sequence.Bind() : false;
    }

    virtual void Pulse(ICXParam* xp) override {
        if(IS_INVALID(m_dispatcher)) return;
        
        // 1. Dispatch signals to listeners (notifying us via OnSignalDetected - currently silent)
        // [v2.2] We don't use OnSignalDetected to trigger the sequence anymore to keep Watcher_Unified logs clean.
        
        if(IS_VALID(xp)) {
            xp.SetContext(m_watcherContext);
            xp.SetSignal(NULL);
        }
        
        // 2. Execute Watcher Sequence (Discovery -> Execute)
        // All XP_LOG calls here will use m_watcherLogger by default.
        if(IS_VALID(m_sequence)) m_sequence.Pulse(xp);

        if(m_sequence.State() == WATCHER_ERROR) {
            string errorDetail = (IS_VALID(xp)) ? xp.GetString() : "Unknown Watcher Error";
            string enhancedError = StringFormat("[WATCHER-FATAL] Circuit Breaker Activated. Reason: %s", errorDetail);
            
            ICXLogger* log = m_watcherContext.GetLogger();
            if(IS_VALID(log)) log.Error(xp, enhancedError);
            Print(enhancedError);
        }

        if(IS_VALID(xp)) {
            xp.SetSignal(NULL);
            xp.SetContext(NULL);
        }
    }
};

void CXWatcherSignalListener::OnSignalDetected(ICXParam* xp) {
    if(IS_VALID(m_owner)) m_owner.OnSignalDetected(xp);
}

#endif
