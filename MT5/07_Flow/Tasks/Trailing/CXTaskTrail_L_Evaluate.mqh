#ifndef CX_TASK_TRAIL_L_EVALUATE_MQH
#define CX_TASK_TRAIL_L_EVALUATE_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\01_Core\Defines\CXDefine.mqh"

/**
 * @class CXTaskTrail_L_Evaluate
 * @brief Determines whether to trigger by calculating the rebound/retraction distance from the extreme point
 * [v2.1 Smart PVB] Implementation of GetRequiredServices
 */
class CXTaskTrail_L_Evaluate : public IXTask {
private:
    ENUM_TRAIL_MODE   m_mode;
    ICXPriceManager*  m_priceMgr;
    ICXSymbolManager* m_symMgr;

public:
    CXTaskTrail_L_Evaluate(ENUM_TRAIL_MODE mode) : m_mode(mode), m_priceMgr(NULL), m_symMgr(NULL) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_L_Evaluate_TE" : "Trail_L_Evaluate_TS"; }
    
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

        string extKey = (m_mode == TRAIL_MODE_ENTRY) ? "TE_Extreme_" : "TS_Extreme_";
        extKey += sig.GetSid();
        ICXParam* pExt = ctx.GetParam(extKey);
        if(IS_INVALID(pExt)) return TASK_CONTINUE;

        double extreme = pExt.GetDouble();
        int step = (m_mode == TRAIL_MODE_ENTRY) ? (int)sig.GetTEStep() : (int)sig.GetTSStep();
        if(step <= 0) return TASK_CONTINUE;

        // [v2.3 Fix] Use GetMarketPrice for Entry and GetLiquidationPrice for Exit
        double currentPrice = (m_mode == TRAIL_MODE_ENTRY) ? 
                               m_priceMgr.GetMarketPrice(sig.GetSymbol(), sig.GetDir()) : 
                               m_priceMgr.GetLiquidationPrice(sig.GetSymbol(), sig.GetDir());
        
        double point = m_symMgr.GetPoint(sig.GetSymbol());

        double distance = (m_mode == TRAIL_MODE_ENTRY) ? 
            ((sig.GetDir() == CX_DIR_BUY) ? (currentPrice - extreme) : (extreme - currentPrice)) :
            ((sig.GetDir() == CX_DIR_BUY) ? (extreme - currentPrice) : (currentPrice - extreme));

        if(distance >= step * point) {
            XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, StringFormat("TRIGGERED! Dist: %.1f pt >= Step: %d pt", distance / point, step)));
            xp.SetInt((m_mode == TRAIL_MODE_ENTRY) ? 10 : 20);
        }
        return TASK_CONTINUE;
    }
};

#endif
