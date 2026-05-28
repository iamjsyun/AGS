#ifndef CXSTAGEEXITDISCOVERY_MQH
#define CXSTAGEEXITDISCOVERY_MQH

#include "..\..\Platform\Core\Interfaces\IXStage.mqh"
#include "..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\Platform\Core\Models\CXSignal.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Platform\Core\Sequence\CXSequenceOrchestrator.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageExitDiscovery
 * @brief DB에서 청산 요청 신호(xa_exit=1, xe_status < 20)를 검색하는 단계
 */
class CXStageExitDiscovery : public IXStage {
public:
    CXStageExitDiscovery() {}
    virtual ~CXStageExitDiscovery() {}

    virtual string Name() override { return "Stage_ExitDiscovery"; }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        return true; 
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(repo)) return STATE_UNCHANGED;

        CArrayObj* activeList = new CArrayObj();
        
        int found = repo.LoadExitSignals(activeList);
        if(found > 0) {
            XP_LOG_OK(xp, StringFormat("[WATCHER-EXIT-DISCOVERY] Found %d active exit signals", found));
            ctx.Set("exit_signals", activeList);
            
            CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
            if(IS_VALID(orchestrator)) {
                return orchestrator.ResolveId("WATCHER_EXIT_EXECUTE");
            }
        }

        SAFE_DELETE(activeList);
        CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
        if(IS_VALID(orchestrator)) {
            return orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY");
        }
        return STATE_UNCHANGED;
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
