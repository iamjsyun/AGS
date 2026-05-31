#ifndef TEST_ORDER_VALIDATOR_MQH
#define TEST_ORDER_VALIDATOR_MQH

#include "..\..\02_Domain\Models\CXContext.mqh"
#include "..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\03_Platform\Execution\Platform\CXOrderValidator.mqh"
#include "..\Mocks\MockSymbolManager.mqh"
#include "..\Mocks\MockPriceManager.mqh"

/**
 * @class TestOrderValidator
 * @brief CXOrderValidator의 가격 보정 및 거리 검증 로직을 테스트함
 */
class TestOrderValidator {
public:
    static bool Run() {
        Print("--- Running TestOrderValidator (Subdivision Phase 1) ---");
        bool allPassed = true;

        CXContext ctx;
        MockSymbolManager symMgr;
        MockPriceManager priceMgr(GetPointer(ctx));
        
        ctx.Register("sym_mgr", GetPointer(symMgr));
        ctx.Register("price_mgr", GetPointer(priceMgr));

        CXOrderValidator validator(GetPointer(ctx));
        CXParam xp;
        string sym = "GOLDF#";

        // 1. Buy Limit 가격 보정 테스트 (StopsLevel 위반 시)
        // 상황: 현재 Ask=2000.0, StopsLevel=50 (0.50), 요청가=1999.8
        // 결과: 2000.0 - 0.51(안전마진) = 1999.49 이하로 보정되어야 함
        double requestedBuy = 1999.8;
        double validatedBuy = validator.ValidateExecPrice(GetPointer(xp), sym, CX_DIR_BUY, ORDER_TYPE_BUY_LIMIT, requestedBuy);
        
        if(validatedBuy < requestedBuy) {
            PrintFormat("  [PASS] Buy Limit adjusted: %.5f -> %.5f", requestedBuy, validatedBuy);
        } else {
            PrintFormat("  [FAIL] Buy Limit NOT adjusted: %.5f -> %.5f", requestedBuy, validatedBuy);
            allPassed = false;
        }

        // 2. SL 거리 부족 검증 테스트
        // 상황: Open=2000.0, SL=1999.8 (거리 0.2), 최소거리=0.51
        // 결과: false 반환
        if(!validator.ValidateStops(GetPointer(xp), sym, CX_DIR_BUY, 2000.0, 1999.8, 0)) {
            Print("  [PASS] SL Too Close correctly rejected.");
        } else {
            Print("  [FAIL] SL Too Close was NOT rejected.");
            allPassed = false;
        }

        // 3. 정상 거리 검증 테스트
        if(validator.ValidateStops(GetPointer(xp), sym, CX_DIR_BUY, 2000.0, 1990.0, 2010.0)) {
            Print("  [PASS] Valid Stops correctly accepted.");
        } else {
            Print("  [FAIL] Valid Stops was incorrectly rejected.");
            allPassed = false;
        }

        if(allPassed) Print("--- TestOrderValidator: ALL PASSED ---");
        else Print("--- TestOrderValidator: SOME TESTS FAILED ---");

        return allPassed;
    }
};

#endif
