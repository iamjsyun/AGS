#ifndef CXSTAGEENTRYDISCOVERY_MQH
#define CXSTAGEENTRYDISCOVERY_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Sequence\CXSequenceOrchestrator.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageEntryDiscovery
 * @brief DB에서 신규 진입 신호(xa_entry=1, xe_status < 10)를 검색하는 단계
 */
class CXStageEntryDiscovery : public IXStage {
private:
    bool     m_isPulsed;

public:
    CXStageEntryDiscovery() : m_isPulsed(false) {}
    virtual ~CXStageEntryDiscovery() {}

    virtual string Name() override { return "Stage_EntryDiscovery"; }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        return true; 
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(repo)) return STATE_UNCHANGED;

        CArrayObj* activeList = new CArrayObj();
        
        int found = repo.LoadEntrySignals(activeList);
        if(found > 0) {
            XP_LOG_OK(xp, StringFormat("[WATCHER-ENTRY-DISCOVERY] Found %d active entry signals", found));
            ctx.Set("entry_signals", activeList);
            
            CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
            if(IS_VALID(orchestrator)) {
                return orchestrator.ResolveId("WATCHER_ENTRY_EXECUTE");
            }
        }

        SAFE_DELETE(activeList);
        CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
        if(IS_VALID(orchestrator)) {
            return orchestrator.ResolveId("WATCHER_EXIT_DISCOVERY");
        }
        return STATE_UNCHANGED;
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
