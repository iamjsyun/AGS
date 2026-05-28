#ifndef CX_TASK_ENTRY_L_RISK_MQH
#define CX_TASK_ENTRY_L_RISK_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXRiskManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_L_Risk
 * @brief [Logic] 로트 수량 및 마진 가용성 검증 (SSOC via RiskManager)
 */
class CXTaskEntry_L_Risk : public IXTask {
public:
    virtual string Name() override { return "Entry_L_Risk"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        ICXRiskManager* riskMgr = CX_GET_OBJ(ctx, "risk_mgr", ICXRiskManager);
        ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);

        if(IS_INVALID(sig) || IS_INVALID(riskMgr) || IS_INVALID(priceMgr)) return TASK_BREAK;

        string symbol = sig.GetSymbol();
        double lot = sig.GetLot();
        int dir = sig.GetDir();
        double marketPrice = priceMgr.GetMarketPrice(symbol, dir);

        // 1. 최소/최대 로트 및 볼륨 스텝 검증
        if(!riskMgr.ValidateLot(xp, symbol, lot)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-L-RISK", xp, StringFormat("Lot Violation: %.2f for %s", lot, symbol)));
            return TASK_BREAK;
        }

        // 2. 가용 증거금(Margin) 검증
        if(!riskMgr.CheckMarginAvailability(xp, symbol, dir, lot, marketPrice)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-L-RISK", xp, StringFormat("Insufficient Margin for %s %.2f lot", symbol, lot)));
            return TASK_BREAK;
        }

        // 3. 계좌 레벨 리스크 필터링
        if(!riskMgr.ValidateAccountRisk(xp)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-L-RISK", xp, "Account level risk limit reached."));
            return TASK_BREAK;
        }

        return TASK_CONTINUE;
    }
};

#endif
