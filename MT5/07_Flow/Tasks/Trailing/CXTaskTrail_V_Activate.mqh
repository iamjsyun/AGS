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

        // [v2.3 Fix] Use GetMarketPrice for Entry and GetLiquidationPrice for Exit
        double currentPrice = (m_mode == TRAIL_MODE_ENTRY) ? 
                               m_priceMgr.GetMarketPrice(sig.GetSymbol(), sig.GetDir()) : 
                               m_priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir());
        
        double point = m_symMgr.GetPoint(sig.GetSymbol());
        double dir_sign = (sig.GetDir() == CX_DIR_BUY) ? 1.0 : -1.0;

        bool is_activated = false;
        if(m_mode == TRAIL_MODE_ENTRY) {
            // [v2.3 Fix] Fallback to price_signal if price_open is 0 to prevent premature activation (especially for SELL)
            double refPrice = (sig.GetPriceOpen() > 0) ? sig.GetPriceOpen() : sig.GetPriceSignal();
            if(refPrice <= 0) return TASK_CONTINUE;

            double triggerPrice = refPrice - (threshold * point * dir_sign);
            is_activated = (sig.GetDir() == CX_DIR_BUY) ? (currentPrice <= triggerPrice) : (currentPrice >= triggerPrice);
        } else {
            double openPrice = sig.GetPriceOpen();
            if(openPrice <= 0) return TASK_CONTINUE;

            double profit = (currentPrice - openPrice) * dir_sign;
            is_activated = (profit >= threshold * point);
        }

        if(is_activated) {
            if(IS_INVALID(pActive)) { pActive = new CXParam(); ctx.Set(activeKey, pActive); }
            pActive.SetInt(1);
            
            // [v2.2 Update] Reflect active trailing state in DB for App UI visibility
            IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
            if(IS_VALID(repo)) {
                sig.SetStatus((m_mode == TRAIL_MODE_ENTRY) ? XE_ENTRY_TRAILING : XE_STOP_TRAILING);
                sig.SetStatusMsg((m_mode == TRAIL_MODE_ENTRY) ? 
                                 StringFormat("Trailing Entry Activated (Price: %s)", DoubleToString(currentPrice, m_symMgr.GetDigits(sig.GetSymbol()))) : 
                                 "Trailing Stop Activated (SSTART reached)");
                repo.UpdateStatus(sig);
            }

            // [v2.4] Store TE Start Price for UI comparison in Global Context
            if(m_mode == TRAIL_MODE_ENTRY) {
                ICXContext* globalCtx = CX_GET_OBJ(ctx, "global_ctx", ICXContext);
                if(IS_VALID(globalCtx)) {
                    string startPriceKey = "TE_StartPrice_" + sig.GetSid();
                    ICXParam* pStart = new CXParam();
                    pStart.SetDouble(currentPrice);
                    globalCtx.Set(startPriceKey, pStart);
                }
            }

            XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, StringFormat("Trailing ACTIVATED! Current Price: %s", DoubleToString(currentPrice, m_symMgr.GetDigits(sig.GetSymbol())))));
            if(m_mode == TRAIL_MODE_EXIT) return SESSION_TRAILING_STOP;
        }
        return TASK_CONTINUE;
    }
};

#endif
