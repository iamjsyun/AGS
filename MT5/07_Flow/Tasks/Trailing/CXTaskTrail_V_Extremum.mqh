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

public:
    CXTaskTrail_V_Extremum(ENUM_TRAIL_MODE mode) : m_mode(mode), m_priceMgr(NULL) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_V_Extremum_TE" : "Trail_V_Extremum_TS"; }
    
    virtual string GetRequiredServices() override { return "price_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        if(IS_INVALID(m_priceMgr)) return false;
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
            if(m_mode == TRAIL_MODE_ENTRY) {
                is_new_extreme = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice < lastExt) : (currentPrice > lastExt);
            } else {
                is_new_extreme = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice > lastExt) : (currentPrice < lastExt);
            }
        }

        if(is_new_extreme) pExt.SetDouble(currentPrice);
        return TASK_CONTINUE;
    }
};

#endif
