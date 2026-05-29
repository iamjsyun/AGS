#ifndef CXSIGNALWATCHER_MQH
#define CXSIGNALWATCHER_MQH

#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Interfaces\ICXConfig.mqh"
#include "..\..\Core\Interfaces\ICXParam.mqh"
#include "..\..\Core\Interfaces\ICXFluentSequence.mqh"
#include "..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Core\Interfaces\ICXContext.mqh"
#include "..\..\Core\Interfaces\ICXServiceFactory.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Sequence\CXSequenceOrchestrator.mqh"

/**
 * @class CXSignalWatcher
 * @brief DB 신호 테이블을 감시하고 적절한 자산 태스크에 할당하는 모듈 (독립 로그 지원)
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
            m_watcherContext.Register("logger", m_watcherLogger);
            m_watcherContext.Register("factory", factory);
        }

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
        SAFE_DELETE(m_sequence);
        SAFE_DELETE(m_watcherContext);
        SAFE_DELETE(m_watcherLogger);
    }

    virtual void Pulse(ICXParam* xp) override {
        if(IS_INVALID(m_sequence)) return;
        
        if(IS_VALID(xp)) {
            xp.SetContext(m_watcherContext);
            xp.SetSignal(NULL);
        }
        
        m_sequence.Pulse(xp);

        if(m_sequence.State() == WATCHER_ERROR) {
            string errorDetail = (IS_VALID(xp)) ? xp.GetString() : "Unknown Watcher Error";
            string enhancedError = StringFormat("[WATCHER-FATAL] Circuit Breaker Activated. Reason: %s", errorDetail);
            
            ICXLogger* log = m_watcherContext.GetLogger();
            if(IS_VALID(log)) log.Error(xp, enhancedError);
            Print(enhancedError);
        }
    }
};

#endif
