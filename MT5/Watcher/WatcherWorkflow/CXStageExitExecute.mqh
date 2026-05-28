#ifndef CXSTAGEEXITEXECUTE_MQH
#define CXSTAGEEXITEXECUTE_MQH

#include "..\..\Platform\Core\Interfaces\IXStage.mqh"
#include "..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\Platform\Core\Models\CXSignal.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Platform\Core\Sequence\CXSequenceOrchestrator.mqh"
#include "..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\Platform\Shared\Logging\CXMessageProvider.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageExitExecute
 * @brief [v18.30] 청산 신호 발견 시 AssetManager를 통해 물리 자산을 원자적으로 제거하는 단계
 */
class CXStageExitExecute : public IXStage {
public:
    CXStageExitExecute() {}
    virtual ~CXStageExitExecute() {}

    virtual string Name() override { return "Stage_ExitExecute"; }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "exit_signals", CArrayObj);
        return (IS_VALID(activeList) && activeList.Total() > 0);
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "exit_signals", CArrayObj);
        ICXAssetManager* assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);

        if(IS_INVALID(activeList) || IS_INVALID(assetMgr)) {
            CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
            return IS_VALID(orchestrator) ? orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY") : STATE_UNCHANGED;
        }

        int total = activeList.Total();
        
        // [v1.0 Scenario G] Massive Zombie Re-sweep
        // If 5 or more exit signals are pending, trigger a bulk SweepByMagic for high-efficiency liquidation.
        if(total >= 5) {
            IXExitManager* exitMgr = CX_GET_OBJ(ctx, "exit_mgr", IXExitManager);
            if(IS_VALID(exitMgr)) {
                XP_LOG_WARN(xp, StringFormat("[WATCHER-EXIT] Massive Liquidation Detected (%d signals). Triggering Bulk Sweep...", total));
                // We'll collect unique magics to sweep. For simplicity, we sweep magics from all signals in the list.
                for(int i = 0; i < total; i++) {
                    ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
                    if(IS_VALID(sig)) {
                        exitMgr.SweepByMagic(xp, sig.GetMagic());
                    }
                }
            }
        }

        for(int i = 0; i < total; i++) {
            ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
            if(IS_INVALID(sig)) continue;

            xp.SetSignal(sig);
            string sid = sig.GetSid();

            // [Atomic Execution] AssetManager에게 청산 집행 위임
            if(assetMgr.ExecuteExit(xp, sid)) {
                XP_LOG_OK(xp, StringFormat("[WATCHER-EXIT] Liquidation Success for SID:%s", sid));
                // [v18.38 Fix] DB 상태를 청산 완료(20)로 명확히 마킹 (xe_status=20, xa_exit=2)
                IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
                if(IS_VALID(repo)) {
                    sig.SetXAExit(XA_CLOSED_COMPLETED);
                    CXMessageProvider::UpdateStatus(sig, XE_CLOSED_SIGNAL, "Liquidation Success. Asset cleared.");
                    repo.UpdateStatus(sig);
                }
            } else {
                XP_LOG_ERROR(xp, StringFormat("[WATCHER-EXIT] Liquidation Failed for SID:%s", sid));
            }
        }

        xp.SetSignal(NULL);
        ctx.Remove("exit_signals");
        SAFE_DELETE(activeList); // Atomic Batch Cleanup

        CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
        return IS_VALID(orchestrator) ? orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY") : STATE_UNCHANGED;
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
