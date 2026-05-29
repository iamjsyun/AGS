#ifndef CXSTAGEENTRYEXECUTE_MQH
#define CXSTAGEENTRYEXECUTE_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Sequence\CXSequenceOrchestrator.mqh"
#include "..\..\Core\Logger\CXAuditFormatter.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageEntryExecute
 * @brief [v18.30] 신규 진입 신호를 AssetManager를 통해 원자적으로 접수하는 단계
 */
class CXStageEntryExecute : public IXStage {
public:
    CXStageEntryExecute() {}
    virtual ~CXStageEntryExecute() {}

    virtual string Name() override { return "Stage_EntryExecute"; }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "entry_signals", CArrayObj);
        return (IS_VALID(activeList) && activeList.Total() > 0);
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "entry_signals", CArrayObj);
        ICXAssetManager* assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);

        if(IS_INVALID(activeList) || IS_INVALID(assetMgr)) {
            CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
            return IS_VALID(orchestrator) ? orchestrator.ResolveId("WATCHER_EXIT_DISCOVERY") : STATE_UNCHANGED;
        }

        int total = activeList.Total();
        for(int i = 0; i < total; i++) {
            ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
            if(IS_INVALID(sig)) continue;

            xp.SetSignal(sig);
            
            // [Atomic Execution] AssetManager에게 주문 접수 위임
            ulong ticket = assetMgr.ExecuteEntry(xp);
            
            if(ticket > 0) {
                XP_LOG_OK(xp, StringFormat("[WATCHER-ENTRY] Reception Success. Ticket:%I64u", ticket));
            } else {
                XP_LOG_ERROR(xp, "[WATCHER-ENTRY] Reception Failed.");
            }
        }

        xp.SetSignal(NULL);
        ctx.Remove("entry_signals");
        SAFE_DELETE(activeList); // Atomic Batch Cleanup

        CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
        return IS_VALID(orchestrator) ? orchestrator.ResolveId("WATCHER_EXIT_DISCOVERY") : STATE_UNCHANGED;
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
