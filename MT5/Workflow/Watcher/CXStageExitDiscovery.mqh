#ifndef CXSTAGEEXITDISCOVERY_MQH
#define CXSTAGEEXITDISCOVERY_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Interfaces\ICXSequenceOrchestrator.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageExitDiscovery
 * @brief DB에서 청산 요청 신호(xa_exit=1, xe_status < 20)를 검색하는 단계
 */
class CXStageExitDiscovery : public IXStage {
private:
    IRepository*             m_repo;
    ICXSequenceOrchestrator* m_orchestrator;

public:
    CXStageExitDiscovery() : m_repo(NULL), m_orchestrator(NULL) {}
    virtual ~CXStageExitDiscovery() {}

    virtual string Name() override { return "Stage_ExitDiscovery"; }

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
        
        int found = m_repo.LoadExitSignals(activeList);
        if(found > 0) {
            XP_LOG_OK(xp, StringFormat("[WATCHER-EXIT-DISCOVERY] Found %d active exit signals", found));
            ctx.Set("exit_signals", activeList);
            
            return m_orchestrator.ResolveId("WATCHER_EXIT_EXECUTE");
        }

        SAFE_DELETE(activeList);
        return m_orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY");
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
