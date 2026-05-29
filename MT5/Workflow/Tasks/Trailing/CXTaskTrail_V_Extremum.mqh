#ifndef CX_TASK_TRAIL_V_EXTREMUM_MQH
#define CX_TASK_TRAIL_V_EXTREMUM_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Models\CXParam.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\Core\Defines\CXDefine.mqh"

/**
 * @class CXTaskTrail_V_Extremum
 * @brief [Verify] 활성화된 상태에서 최극점(Extreme) 가격을 추적하고 기록
 */
class CXTaskTrail_V_Extremum : public IXTask {
private:
    ENUM_TRAIL_MODE m_mode;

public:
    CXTaskTrail_V_Extremum(ENUM_TRAIL_MODE mode) : m_mode(mode) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_V_Extremum_TE" : "Trail_V_Extremum_TS"; }
    
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_CONTINUE;

        // 활성화 상태 확인
        string activeKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Active_" : "TS_Active_";
        activeKey += sig.GetSid();
        ICXParam* pActive = ctx.GetParam(activeKey);
        if(IS_INVALID(pActive) || pActive.GetInt() != 1) return TASK_CONTINUE;

        ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        double currentPrice = IS_VALID(priceMgr) ? priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir()) : 
                             SymbolInfoDouble(sig.GetSymbol(), (sig.GetDir() == CX_DIR_BUY) ? SYMBOL_BID : SYMBOL_ASK);

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
                // 진트 극점: BUY(최저), SELL(최고)
                is_new_extreme = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice < lastExt) : (currentPrice > lastExt);
            } else {
                // 익트 극점: BUY(최고), SELL(최저)
                is_new_extreme = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice > lastExt) : (currentPrice < lastExt);
            }
        }

        if(is_new_extreme) {
            pExt.SetDouble(currentPrice);
        }

        return TASK_CONTINUE;
    }
};

#endif
