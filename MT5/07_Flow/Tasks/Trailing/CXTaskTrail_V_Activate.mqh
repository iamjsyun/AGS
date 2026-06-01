#ifndef CX_TASK_TRAIL_V_ACTIVATE_MQH
#define CX_TASK_TRAIL_V_ACTIVATE_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\01_Core\Defines\CXDefine.mqh"

/**
 * @class CXTaskTrail_V_Activate
 * @brief Monitors whether trailing (TE/TS) is activated and records the state
 * [v2.1 Smart PVB] Implementation of GetRequiredServices
 */
class CXTaskTrail_V_Activate : public IXTask {
private:
    ENUM_TRAIL_MODE   m_mode;
    ICXPriceManager*  m_priceMgr;
    ICXSymbolManager* m_symMgr;

public:
    CXTaskTrail_V_Activate(ENUM_TRAIL_MODE mode) : m_mode(mode), m_priceMgr(NULL), m_symMgr(NULL) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_V_Activate_TE" : "Trail_V_Activate_TS"; }
    
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
        if(IS_VALID(pActive) && pActive.GetInt() == 1) return TASK_CONTINUE;

        int threshold = (m_mode == TRAIL_MODE_ENTRY) ? (int)sig.GetTEStart() : (int)sig.GetTSStart();
        if(threshold <= 0) return TASK_CONTINUE;

        double currentPrice = m_priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir());
        double point = m_symMgr.GetPoint(sig.GetSymbol());
        double dir_sign = (sig.GetDir() == CX_DIR_BUY) ? 1.0 : -1.0;

        bool is_activated = false;
        if(m_mode == TRAIL_MODE_ENTRY) {
            double entryPrice = sig.GetPriceOpen();
            double triggerPrice = entryPrice - (threshold * point * dir_sign);
            is_activated = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice <= triggerPrice) : (currentPrice >= triggerPrice);
        } else {
            double openPrice = sig.GetPriceOpen();
            double profit = (currentPrice - openPrice) * dir_sign;
            is_activated = (profit >= threshold * point);
        }

        if(is_activated) {
            if(IS_INVALID(pActive)) { pActive = new CXParam(); ctx.Set(activeKey, pActive); }
            pActive.SetInt(1);
            XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, "Trailing ACTIVATED!"));
            if(m_mode == TRAIL_MODE_EXIT) return SESSION_TRAILING_STOP;
        }
        return TASK_CONTINUE;
    }
};

#endif
