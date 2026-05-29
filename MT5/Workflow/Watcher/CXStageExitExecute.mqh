#ifndef CXSTAGEEXITEXECUTE_MQH
#define CXSTAGEEXITEXECUTE_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Core\Interfaces\IRepository.mqh"
#include "..\..\Core\Models\CXSignal.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Interfaces\ICXSequenceOrchestrator.mqh"
#include "..\..\Core\Logger\CXAuditFormatter.mqh"
#include "..\..\Core\Logger\CXMessageProvider.mqh"

#include <Arrays\ArrayObj.mqh>

/**
 * @class CXStageExitExecute
 * @brief [v18.30] 청산 신호 발견 시 AssetManager를 통해 물리 자산을 원자적으로 제거하는 단계
 */
class CXStageExitExecute : public IXStage {
private:
    ICXAssetManager*         m_assetMgr;
    IXExitManager*           m_exitMgr;
    IRepository*             m_repo;
    ICXSequenceOrchestrator* m_orchestrator;

public:
    CXStageExitExecute() : m_assetMgr(NULL), m_exitMgr(NULL), m_repo(NULL), m_orchestrator(NULL) {}
    virtual ~CXStageExitExecute() {}

    virtual string Name() override { return "Stage_ExitExecute"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        m_exitMgr = CX_GET_OBJ(ctx, "exit_mgr", IXExitManager);
        m_repo = CX_GET_OBJ(ctx, "repo", IRepository);
        m_orchestrator = CX_GET_OBJ(ctx, "orchestrator", ICXSequenceOrchestrator);
        if(IS_INVALID(m_assetMgr) || IS_INVALID(m_orchestrator) || IS_INVALID(m_repo)) return false;
        return IXStage::Bind(ctx);
    }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "exit_signals", CArrayObj);
        return (IS_VALID(activeList) && activeList.Total() > 0);
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        CArrayObj* activeList = CX_GET_OBJ(ctx, "exit_signals", CArrayObj);

        if(IS_INVALID(activeList)) {
            return m_orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY");
        }

        int total = activeList.Total();
        
        // [v1.0 Scenario G] Massive Zombie Re-sweep
        // If 5 or more exit signals are pending, trigger a bulk SweepByMagic for high-efficiency liquidation.
        if(total >= 5 && IS_VALID(m_exitMgr)) {
            XP_LOG_WARN(xp, StringFormat("[WATCHER-EXIT] Massive Liquidation Detected (%d signals). Triggering Bulk Sweep...", total));
            // We'll collect unique magics to sweep. For simplicity, we sweep magics from all signals in the list.
            for(int i = 0; i < total; i++) {
                ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
                if(IS_VALID(sig)) {
                    m_exitMgr.SweepByMagic(xp, sig.GetMagic());
                }
            }
        }

        for(int i = 0; i < total; i++) {
            ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
            if(IS_INVALID(sig)) continue;

            xp.SetSignal(sig);
            string sid = sig.GetSid();

            // [Atomic Execution] AssetManager에게 청산 집행 위임
            if(m_assetMgr.ExecuteExit(xp, sid)) {
                XP_LOG_OK(xp, StringFormat("[WATCHER-EXIT] Liquidation Success for SID:%s", sid));
                // [v18.38 Fix] DB 상태를 청산 완료(20)로 명확히 마킹 (xe_status=20, xa_exit=2)
                sig.SetXAExit(XA_CLOSED_COMPLETED);
                CXMessageProvider::UpdateStatus(sig, XE_CLOSED_SIGNAL, "Liquidation Success. Asset cleared.");
                m_repo.UpdateStatus(sig);
            } else {
                XP_LOG_ERROR(xp, StringFormat("[WATCHER-EXIT] Liquidation Failed for SID:%s", sid));
            }
        }

        xp.SetSignal(NULL);
        ctx.Remove("exit_signals");
        SAFE_DELETE(activeList); // Atomic Batch Cleanup

        return m_orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY");
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
