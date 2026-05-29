#ifndef CX_TASK_TRAIL_L_EVALUATE_MQH
#define CX_TASK_TRAIL_L_EVALUATE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Models\CXParam.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\Platform\Engine\Trailing\CXTrailingEngine.mqh"

/**
 * @class CXTaskTrail_L_Evaluate
 * @brief [Logic] 극점 대비 반등/되돌림 거리를 계산하여 트리거 여부 판단
 */
class CXTaskTrail_L_Evaluate : public IXTask {
private:
    ENUM_TRAIL_MODE m_mode;

public:
    CXTaskTrail_L_Evaluate(ENUM_TRAIL_MODE mode) : m_mode(mode) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_L_Evaluate_TE" : "Trail_L_Evaluate_TS"; }
    
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_CONTINUE;

        // 극점 데이터 확인
        string extKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Extreme_" : "TS_Extreme_";
        extKey += sig.GetSid();
        ICXParam* pExt = ctx.GetParam(extKey);
        if(IS_INVALID(pExt)) return TASK_CONTINUE;

        double extreme = pExt.GetDouble();
        int step = (m_mode == TRAIL_MODE_ENTRY) ? (int)sig.GetTEStep() : (int)sig.GetTSStep();
        if(step <= 0) return TASK_CONTINUE;

        ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        ICXSymbolManager* symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
        
        double currentPrice = IS_VALID(priceMgr) ? priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir()) : 
                             SymbolInfoDouble(sig.GetSymbol(), (sig.GetDir() == CX_DIR_BUY) ? SYMBOL_BID : SYMBOL_ASK);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(sig.GetSymbol()) : SymbolInfoDouble(sig.GetSymbol(), SYMBOL_POINT);

        double distance = 0;
        bool is_triggered = false;

        if(m_mode == TRAIL_MODE_ENTRY) {
            // [진트 반등] BUY: Current - Min >= step, SELL: Max - Current >= step
            distance = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice - extreme) : (extreme - currentPrice);
        } else {
            // [익트 되돌림] BUY: Max - Current >= step, SELL: Current - Min >= step
            distance = (sig.GetDir() == CX_DIR_BUY) ? (extreme - currentPrice) : (currentPrice - extreme);
        }

        // [v11.11 Mandate] >= 연산자 사용
        if(distance >= step * point) {
            is_triggered = true;
            XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, 
                StringFormat("TRIGGERED! Dist: %.1f pt >= Step: %d pt", distance / point, step)));
            
            // 전이 코드 설정 (TE: 10, TS: 20)
            int code = (m_mode == TRAIL_MODE_ENTRY) ? 10 : 20;
            xp.SetInt(code);
        }

        return TASK_CONTINUE;
    }
};

#endif
