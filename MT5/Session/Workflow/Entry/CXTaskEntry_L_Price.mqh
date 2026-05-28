#ifndef CX_TASK_ENTRY_L_PRICE_MQH
#define CX_TASK_ENTRY_L_PRICE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXGuard.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_L_Price
 * @brief [Logic] 진입 가격, SL, TP 계산 및 StopLevel 검증
 */
class CXTaskEntry_L_Price : public IXTask {
public:
    virtual string Name() override { return "Entry_L_Price"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        
        // [v16.16 Fix] Initial Entry Price Protection
        // 진입 가격이 이미 계산되어 있다면 (0이 아니면) 재계산하지 않고 유지한다.
        // 이를 통해 SL/TP가 시장가에 따라 매 틱 변하는 오류를 방지한다.
        if(IS_VALID(sig) && sig.GetPriceOpen() > 0) return TASK_CONTINUE;

        ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
        IXGuard* guard = CX_GET_OBJ(ctx, "guard", IXGuard);

        if(IS_INVALID(sig) || IS_INVALID(priceMgr)) return TASK_BREAK;

        string symbol = sig.GetSymbol();
        int dir = sig.GetDir();
        double marketPrice = priceMgr.GetMarketPrice(symbol, dir);

        // 1. 실행 가격 계산 (Pending Order용 또는 Market용)
        double execPrice = 0;
        if(sig.GetType() == ORDER_LIMIT || sig.GetType() == ORDER_STOP) {
            execPrice = sig.GetPriceSignal();
        } else {
            // [v14.31 Spec Sync] 최초 진입 시에는 ELIMIT을 사용하여 안전 거리를 확보한다.
            double offset = (sig.GetType() == ORDER_MARKET) ? 0 : sig.GetTELimit();
            execPrice = priceMgr.CalculateExecPrice(xp, symbol, dir, sig.GetType(), offset);
        }
        
        // 2. SL/TP 가격 계산 (BasePrice 기반)
        double basePrice = (sig.GetType() == ORDER_MARKET) ? marketPrice : execPrice;
        double finalSL = priceMgr.CalculateSL(xp, symbol, dir, basePrice, sig.GetSL());
        double finalTP = priceMgr.CalculateTP(xp, symbol, dir, basePrice, sig.GetTP());

        // 3. StopLevel 검증 및 보정 (10016 에러 방지)
        if(IS_VALID(guard)) {
            // 시장가 진입 시 Liquidation Price 기준으로 검증
            double vBase = (sig.GetType() == ORDER_MARKET) ? priceMgr.GetLiquidationPrice(symbol, dir) : basePrice;
            
            if(finalSL > 0 && !guard.ValidateStopLevel(symbol, vBase, finalSL)) {
                XP_LOG_WARN(xp, CXAuditFormatter::Build("TASK-PRICE", xp, StringFormat("SL too close (Base:%.5f, SL:%.5f). Resetting to 0.", vBase, finalSL)));
                finalSL = 0;
            }
            if(finalTP > 0 && !guard.ValidateStopLevel(symbol, vBase, finalTP)) {
                XP_LOG_WARN(xp, CXAuditFormatter::Build("TASK-PRICE", xp, StringFormat("TP too close (Base:%.5f, TP:%.5f). Resetting to 0.", vBase, finalTP)));
                finalTP = 0;
            }
        }

        // [v14.30 Mandate Sync] 
        // 진입 시점의 TE-Limit 검증(하드 거절)을 제거하고, 
        // 이후 Trailing 단계에서 동적으로 간격을 유지하도록 전략 수정.

        // 4. 결과값 모델 동기화 (Shadowing)
        sig.SetPriceOpen(execPrice);
        sig.SetPriceSL(finalSL);
        sig.SetPriceTP(finalTP);

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-L-PRICE", xp, "Price Calculation Success"));

        return TASK_CONTINUE;
    }
};

#endif
