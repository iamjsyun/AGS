#ifndef CXSTAGEENTRYEXECUTE_MQH
#define CXSTAGEENTRYEXECUTE_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Interfaces\ICXSequenceOrchestrator.mqh"
#include "..\..\Core\Logger\CXAuditFormatter.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageEntryExecute
 * @brief [v18.30] 신규 진입 신호를 AssetManager를 통해 원자적으로 접수하는 단계
 */
class CXStageEntryExecute : public IXStage {
private:
    ICXAssetManager*         m_assetMgr;
    ICXSequenceOrchestrator* m_orchestrator;

public:
    CXStageEntryExecute() : m_assetMgr(NULL), m_orchestrator(NULL) {}
    virtual ~CXStageEntryExecute() {}

    virtual string Name() override { return "Stage_EntryExecute"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        m_orchestrator = CX_GET_OBJ(ctx, "orchestrator", ICXSequenceOrchestrator);
        if(IS_INVALID(m_assetMgr) || IS_INVALID(m_orchestrator)) return false;
        return IXStage::Bind(ctx);
    }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "entry_signals", CArrayObj);
        return (IS_VALID(activeList) && activeList.Total() > 0);
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "entry_signals", CArrayObj);

        if(IS_INVALID(activeList)) {
            return m_orchestrator.ResolveId("WATCHER_EXIT_DISCOVERY");
        }

        int total = activeList.Total();
        for(int i = 0; i < total; i++) {
            ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
            if(IS_INVALID(sig)) continue;

            xp.SetSignal(sig);
            
            // [Atomic Execution] AssetManager에게 주문 접수 위임
            ulong ticket = m_assetMgr.ExecuteEntry(xp);
            
            if(ticket > 0) {
                XP_LOG_OK(xp, StringFormat("[WATCHER-ENTRY] Reception Success. Ticket:%I64u", ticket));
            } else {
                XP_LOG_ERROR(xp, "[WATCHER-ENTRY] Reception Failed.");
            }
        }

        xp.SetSignal(NULL);
        ctx.Remove("entry_signals");
        SAFE_DELETE(activeList); // Atomic Batch Cleanup

        return m_orchestrator.ResolveId("WATCHER_EXIT_DISCOVERY");
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
