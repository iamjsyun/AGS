#ifndef CXRISKMANAGER_MQH
#define CXRISKMANAGER_MQH

#include "..\..\01_Core\Interfaces\ICXRiskManager.mqh"
#include "..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\01_Core\Defines\CXDefine.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\Execution\Platform\CXRiskEvaluator.mqh"

/**
 * @class CXRiskManager
 * @brief Specialized implementation for risk and money management (v13.6 Subdivision)
 */
class CXRiskManager : public ICXRiskManager {
private:
    ICXContext* m_ctx;

public:
    CXRiskManager(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXRiskManager() {}

    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") override {
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        return CXAuditFormatter::Build(actionLabel, xp, StringFormat("FreeMargin:%.2f, Equity:%.2f", freeMargin, equity));
    }

    virtual bool ValidateLot(ICXParam* xp, string symbol, double lot) override {
        if(!CXRiskEvaluator::IsLotWithinGlobalLimit(xp, lot)) return false;

        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double minLot = IS_VALID(symMgr) ? symMgr.GetMinLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = IS_VALID(symMgr) ? symMgr.GetMaxLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double step   = IS_VALID(symMgr) ? symMgr.GetLotStep(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        if(lot < minLot || lot > maxLot) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-LOT-INVALID", xp, StringFormat("Lot:%.2f (Min:%.2f, Max:%.2f)", lot, minLot, maxLot)));
            return false;
        }
        return true;
    }

    virtual double NormalizeLot(string symbol, double lot) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double minLot = IS_VALID(symMgr) ? symMgr.GetMinLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double step   = IS_VALID(symMgr) ? symMgr.GetLotStep(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        double normalized = minLot + MathFloor((lot - minLot) / step + 0.0000001) * step;
        int digits = (step == 0.01) ? 2 : ((step == 0.1) ? 1 : 0);
        return NormalizeDouble(normalized, digits);
    }

    virtual double CalculateRequiredMargin(string symbol, int dir, double lot, double price) override {
        double margin = 0;
        if(!OrderCalcMargin((dir == CX_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, symbol, lot, price, margin)) return -1;
        return margin;
    }

    virtual bool CheckMarginAvailability(ICXParam* xp, string symbol, int dir, double lot, double price) override {
        double required = CalculateRequiredMargin(symbol, dir, lot, price);
        if(required < 0) { XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-MARGIN-CALC-FAIL", xp)); return false; }
        return CXRiskEvaluator::IsMarginSufficient(xp, m_ctx, required);
    }

    virtual bool ValidateAccountRisk(ICXParam* xp) override { return true; }
};

#endif
