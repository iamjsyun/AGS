#ifndef CX_TASK_ENTRY_P_FINALIZE_MQH
#define CX_TASK_ENTRY_P_FINALIZE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Shared\Graphics\CXChartVisualizer.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXSymbolManager.mqh"

/**
 * @class CXTaskEntry_P_Finalize
 * @brief [Persistence] DB 상태 최종 확정
 */
class CXTaskEntry_P_Finalize : public IXTask {
public:
    virtual string Name() override { return "Entry_P_Finalize"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        int targetStatus = (sig.GetType() == ORDER_MARKET) ? XE_EXECUTED : XE_PENDING_PLACED;
        string msg = (targetStatus == XE_EXECUTED) ? "Entry Executed (Market)" : "Entry Pending Placed (Trailing)";
        int nextSessionPhase = (targetStatus == XE_EXECUTED) ? SESSION_ACTIVE : TASK_CONTINUE;

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("TASK-FINALIZE", xp, StringFormat("Committing Final State: %d (%s)", targetStatus, msg)));

        CXMessageProvider::UpdateStatus(sig, targetStatus, msg);
        if(repo.UpdateStatus(sig)) {
            // [v16.23 Initial Visual] 대기 오더 접수 직후 활성화 트리거 라인 생성 (price_signal 기준) [v11.11 >= Mandate]
            if(targetStatus == XE_PENDING_PLACED && sig.GetTEStart() >= 1) {
                ICXSymbolManager* symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
                double point = IS_VALID(symMgr) ? symMgr.GetPoint(sig.GetSymbol()) : SymbolInfoDouble(sig.GetSymbol(), SYMBOL_POINT);
                double dir_sign = (sig.GetDir() == CX_DIR_BUY) ? -1.0 : 1.0;
                
                double priceSignal = sig.GetPriceSignal();
                if(priceSignal <= 0) priceSignal = sig.GetPriceOpen() - (sig.GetTELimit() * point * dir_sign); // price_signal 복원
                
                if(priceSignal > 0) {
                    double triggerLine = priceSignal + (sig.GetTEStart() * point * dir_sign);
                    CXChartVisualizer::DrawTEStart(ctx, sig, triggerLine, "CXTaskEntry_P_Finalize");
                    
                    // [v18.36] Mark as initially drawn to prevent redundant redraw in Improve task
                    string drawKey = "TE_InitialDraw_" + sig.GetSid();
                    ICXParam* pDraw = new CXParam();
                    pDraw.SetInt(1);
                    ctx.Set(drawKey, pDraw);
                }
            }

            XP_LOG_OK(xp, CXAuditFormatter::Build("TASK-FINALIZE", xp, StringFormat("SUCCESS: DB Updated. Result: %d", nextSessionPhase)));
            return nextSessionPhase;
        }

        XP_LOG_WARN(xp, CXAuditFormatter::Build("TASK-FINALIZE", xp, "YIELD: DB Update Delayed. Retrying..."));
        return TASK_YIELD;
    }
};

#endif
