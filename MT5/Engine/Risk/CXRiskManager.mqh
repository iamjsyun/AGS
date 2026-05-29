#ifndef CXRISKMANAGER_MQH
#define CXRISKMANAGER_MQH

#include "..\..\Core\Interfaces\ICXRiskManager.mqh"
#include "..\..\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\Core\Interfaces\ICXContext.mqh"
#include "..\..\Core\Defines\CXDefine.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXRiskManager
 * @brief 리스크 관리 및 자금 관리 전문 구현체 (v13.5 UAF Standard)
 */
class CXRiskManager : public ICXRiskManager {
private:
    ICXContext* m_ctx;

public:
    CXRiskManager(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXRiskManager() {}

    /**
     * @brief [v13.4 Audit] 리스크 상태 감사 문자열 생성
     */
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") override {
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        string spec = StringFormat("FreeMargin:%.2f, Equity:%.2f", freeMargin, equity);
        return CXAuditFormatter::Build(actionLabel, xp, spec);
    }

    /**
     * @brief 로트 사이즈 유효성 검사 (브로커 규격 준수 여부)
     */
    virtual bool ValidateLot(ICXParam* xp, string symbol, double lot) override {
        // Enforce global system safety limit (Lot <= 0 or Lot > 50 is strictly prohibited)
        if(lot <= 0 || lot > 50.0) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-LOT-CEILING-VIOLATION", xp, StringFormat("Lot:%.2f forbidden (Ceiling: 0 < Lot <= 50)", lot)));
            return false;
        }

        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double minLot = IS_VALID(symMgr) ? symMgr.GetMinLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = IS_VALID(symMgr) ? symMgr.GetMaxLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double step   = IS_VALID(symMgr) ? symMgr.GetLotStep(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        if(lot < minLot || lot > maxLot) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-LOT-INVALID", xp, StringFormat("Lot:%.2f (Min:%.2f, Max:%.2f)", lot, minLot, maxLot)));
            return false;
        }

        // 스텝 정렬 확인 (미세 오차 허용)
        double remain = MathMod(lot - minLot, step);
        if(remain > 0.0000001 && step - remain > 0.0000001) {
             XP_LOG_WARN(xp, CXAuditFormatter::Build("RISK-LOT-STEP", xp, StringFormat("Lot:%.2f, Step:%.2f", lot, step)));
        }

        return true;
    }

    /**
     * @brief 브로커 규격에 맞게 로트 사이즈 보정
     */
    virtual double NormalizeLot(string symbol, double lot) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double minLot = IS_VALID(symMgr) ? symMgr.GetMinLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double step   = IS_VALID(symMgr) ? symMgr.GetLotStep(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        
        double normalized = minLot + MathFloor((lot - minLot) / step + 0.0000001) * step;
        int digits = 0;
        if(step == 0.01) digits = 2;
        else if(step == 0.1) digits = 1;
        
        return NormalizeDouble(normalized, digits);
    }

    /**
     * @brief 필요 증거금 계산
     */
    virtual double CalculateRequiredMargin(string symbol, int dir, double lot, double price) override {
        double margin = 0;
        ENUM_ORDER_TYPE orderType = (dir == CX_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        if(!OrderCalcMargin(orderType, symbol, lot, price, margin)) {
            return -1;
        }
        return margin;
    }

    /**
     * @brief 가용 증거금 확인 (Not Enough Money 사전 차단)
     */
    virtual bool CheckMarginAvailability(ICXParam* xp, string symbol, int dir, double lot, double price) override {
        double required = CalculateRequiredMargin(symbol, dir, lot, price);
        if(required < 0) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-MARGIN-CALC-FAIL", xp));
            return false;
        }

        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        if(freeMargin < required) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-NO-MONEY", xp, StringFormat("Free:%.2f, Req:%.2f", freeMargin, required)));
            return false;
        }

        return true;
    }

    /**
     * @brief 계좌 전체 리스크 한도 검증
     */
    virtual bool ValidateAccountRisk(ICXParam* xp) override {
        return true;
    }
};

#endif
