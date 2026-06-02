#ifndef CX_TASK_TRAIL_V_EXTREMUM_MQH
#define CX_TASK_TRAIL_V_EXTREMUM_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\01_Core\Defines\CXDefine.mqh"

/**
 * @class CXTaskTrail_V_Extremum
 * @brief Tracks and records the recent extreme price while in an active state
 * [v2.1 Smart PVB] Implementation of GetRequiredServices
 */
class CXTaskTrail_V_Extremum : public IXTask {
private:
    ENUM_TRAIL_MODE  m_mode;
    ICXPriceManager* m_priceMgr;
    ICXSymbolManager* m_symMgr;

public:
    CXTaskTrail_V_Extremum(ENUM_TRAIL_MODE mode) : m_mode(mode), m_priceMgr(NULL), m_symMgr(NULL) {}

    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_V_Extremum_TE" : "Trail_V_Extremum_TS"; }

    virtual string GetRequiredServices() override { return "price_mgr, sym_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        m_symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
        if(IS_INVALID(m_priceMgr) || IS_INVALID(m_symMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_CONTINUE;

        string activeKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Active_" : "TS_Active_";
        activeKey += sig.GetSid();
        ICXParam* pActive = ctx.GetParam(activeKey);
        if(IS_INVALID(pActive) || pActive.GetInt() != 1) return TASK_CONTINUE;

        // [v2.3 Fix] Use GetMarketPrice for Entry and GetLiquidationPrice for Exit
        double currentPrice = (m_mode == TRAIL_MODE_ENTRY) ? 
                               m_priceMgr.GetMarketPrice(sig.GetSymbol(), sig.GetDir()) : 
                               m_priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir());

        string extKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Extreme_" : "TS_Extreme_";
        extKey += sig.GetSid();
        ICXParam* pExt = ctx.GetParam(extKey);

        bool is_new_extreme = false;
        if(IS_INVALID(pExt)) {
            pExt = new CXParam();
            ctx.Set(extKey, pExt);
            is_new_extreme = true;
        } else {
            double lastExt = pExt.GetDouble();
            double point = m_symMgr.GetPoint(sig.GetSymbol());
            double step = (m_mode == TRAIL_MODE_ENTRY) ? sig.GetTEStep() : sig.GetTSStep();
            if(step <= 0) step = 1.0; // Default to 1 point if not set

            if(m_mode == TRAIL_MODE_ENTRY) {
                // For Entry Trailing: Move extreme when price moves in favorable direction by at least 'step'
                if(sig.GetDir() == CX_DIR_BUY) {
                    is_new_extreme = (currentPrice <= lastExt - (step * point));
                } else {
                    is_new_extreme = (currentPrice >= lastExt + (step * point));
                }
            } else {
                // For Stop Trailing: Move extreme when price moves in profitable direction by at least 'step'
                if(sig.GetDir() == CX_DIR_BUY) {
                    is_new_extreme = (currentPrice >= lastExt + (step * point));
                } else {
                    is_new_extreme = (currentPrice <= lastExt - (step * point));
                }
            }
        }

        if(is_new_extreme) {
            pExt.SetDouble(currentPrice);

            // [v2.4] Also sync to Global Context for UI display (unify keys)
            ICXContext* globalCtx = CX_GET_OBJ(ctx, "global_ctx", ICXContext);
            if(IS_VALID(globalCtx)) {
                string globalExtKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Extreme_" : "TS_Extreme_";
                globalExtKey += sig.GetSid();
                ICXParam* pGlobalExt = globalCtx.GetParam(globalExtKey);
                if(IS_INVALID(pGlobalExt)) {
                    pGlobalExt = new CXParam();
                    globalCtx.Set(globalExtKey, pGlobalExt);
                }
                pGlobalExt.SetDouble(currentPrice);
            }
        }
        return TASK_CONTINUE;
    }
};

#endif
