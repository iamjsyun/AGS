#ifndef CXSTAGEENTRYDISCOVERY_MQH
#define CXSTAGEENTRYDISCOVERY_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Interfaces\ICXSequenceOrchestrator.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageEntryDiscovery
 * @brief DB에서 신규 진입 신호(xa_entry=1, xe_status < 10)를 검색하는 단계
 */
class CXStageEntryDiscovery : public IXStage {
private:
    bool                     m_isPulsed;
    IRepository*             m_repo;
    ICXSequenceOrchestrator* m_orchestrator;

public:
    CXStageEntryDiscovery() : m_isPulsed(false), m_repo(NULL), m_orchestrator(NULL) {}
    virtual ~CXStageEntryDiscovery() {}

    virtual string Name() override { return "Stage_EntryDiscovery"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        m_orchestrator = CX_GET_OBJ(ctx, "orchestrator", ICXSequenceOrchestrator);
        if(IS_INVALID(m_repo) || IS_INVALID(m_orchestrator)) return false;
        return IXStage::Bind(ctx);
    }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        return true; 
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        CArrayObj* activeList = new CArrayObj();
        
        int found = m_repo.LoadEntrySignals(activeList);
        if(found > 0) {
            XP_LOG_OK(xp, StringFormat("[WATCHER-ENTRY-DISCOVERY] Found %d active entry signals", found));
            ctx.Set("entry_signals", activeList);
            
            return m_orchestrator.ResolveId("WATCHER_ENTRY_EXECUTE");
        }

        SAFE_DELETE(activeList);
        return m_orchestrator.ResolveId("WATCHER_EXIT_DISCOVERY");
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
