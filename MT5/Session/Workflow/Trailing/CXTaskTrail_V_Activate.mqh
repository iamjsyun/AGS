#ifndef CX_TASK_TRAIL_V_ACTIVATE_MQH
#define CX_TASK_TRAIL_V_ACTIVATE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Models\CXParam.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\Platform\Engine\Trailing\CXTrailingEngine.mqh"

/**
 * @class CXTaskTrail_V_Activate
 * @brief [Verify] 트레일링(TE/TS) 활성화 여부를 감시하고 상태를 기록
 */
class CXTaskTrail_V_Activate : public IXTask {
private:
    ENUM_TRAIL_MODE m_mode;

public:
    CXTaskTrail_V_Activate(ENUM_TRAIL_MODE mode) : m_mode(mode) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_V_Activate_TE" : "Trail_V_Activate_TS"; }
    
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_CONTINUE;

        // 이미 활성화된 경우 스킵
        string activeKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Active_" : "TS_Active_";
        activeKey += sig.GetSid();
        ICXParam* pActive = ctx.GetParam(activeKey);
        if(IS_VALID(pActive) && pActive.GetInt() == 1) return TASK_CONTINUE;

        // 설정값 확인
        int threshold = (m_mode == TRAIL_MODE_ENTRY) ? sig.GetTEStart() : sig.GetTSStart();
        if(threshold <= 0) return TASK_CONTINUE;

        ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        ICXSymbolManager* symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
        
        double currentPrice = IS_VALID(priceMgr) ? priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir()) : 
                             SymbolInfoDouble(sig.GetSymbol(), (sig.GetDir() == CX_DIR_BUY) ? SYMBOL_BID : SYMBOL_ASK);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(sig.GetSymbol()) : SymbolInfoDouble(sig.GetSymbol(), SYMBOL_POINT);
        double dir_sign = (sig.GetDir() == CX_DIR_BUY) ? 1.0 : -1.0;

        bool is_activated = false;
        if(m_mode == TRAIL_MODE_ENTRY) {
            // [진트] 가격 하락 시 활성화 (BUY: Price <= Entry - te_start)
            double entryPrice = sig.GetPriceOpen();
            double triggerPrice = entryPrice - (threshold * point * dir_sign);
            is_activated = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice <= triggerPrice) : (currentPrice >= triggerPrice);
        } else {
            // [익트] 수익이 ts_start 이상일 때 활성화 (BUY: Current - Entry >= ts_start)
            double openPrice = sig.GetPriceOpen();
            double profit = (currentPrice - openPrice) * dir_sign;
            is_activated = (profit >= threshold * point);
        }

        if(is_activated) {
            if(IS_INVALID(pActive)) {
                pActive = new CXParam();
                ctx.Set(activeKey, pActive);
            }
            pActive.SetInt(1);
            XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, "Trailing ACTIVATED!"));
            
            // [v1.0] 전이 코드 설정 (TS 활성화 시 POS_TRAILING(15)으로 전이 유도)
            if(m_mode == TRAIL_MODE_EXIT) xp.SetInt(15);
        }

        return TASK_CONTINUE;
    }
};

#endif
