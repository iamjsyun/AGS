#ifndef TEST_PRICE_RISK_SUBDIVISION_MQH
#define TEST_PRICE_RISK_SUBDIVISION_MQH

#include "..\..\02_Domain\Models\CXContext.mqh"
#include "..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\03_Platform\Execution\Platform\CXPriceNormalizer.mqh"
#include "..\..\03_Platform\Execution\Platform\CXRiskEvaluator.mqh"
#include "..\Mocks\MockSymbolManager.mqh"
#include "..\Mocks\MockTerminalPlatform.mqh"

/**
 * @class TestPriceRiskSubdivision
 * @brief CXPriceNormalizer 및 CXRiskEvaluator의 원자적 로직을 검증함
 */
class TestPriceRiskSubdivision {
public:
    static bool Run() {
        Print("--- Running TestPriceRiskSubdivision (Subdivision Phase 1) ---");
        bool allPassed = true;

        CXContext ctx;
        MockSymbolManager symMgr;
        MockTerminalPlatform terminal;
        ctx.Register("sym_mgr", GetPointer(symMgr));
        ctx.Register("terminal_platform", GetPointer(terminal));

        CXParam xp;

        // 1. Price Normalization Test (Gold, 2 Digits, TickSize 0.01)
        double rawPrice = 2000.12345;
        double normPrice = CXPriceNormalizer::Normalize(GetPointer(ctx), "Gold#", rawPrice);
        if(normPrice == 2000.12) {
            Print("  [PASS] Price Normalization (2 Digits) Success.");
        } else {
            PrintFormat("  [FAIL] Price Normalization (2 Digits) Failed. Got: %.5f", normPrice);
            allPassed = false;
        }

        // 2. Risk Evaluation: Lot Ceiling Test
        if(CXRiskEvaluator::IsLotWithinGlobalLimit(GetPointer(xp), 10.0) && 
           !CXRiskEvaluator::IsLotWithinGlobalLimit(GetPointer(xp), 60.0)) {
            Print("  [PASS] Lot Ceiling Validation Success.");
        } else {
            Print("  [FAIL] Lot Ceiling Validation Failed.");
            allPassed = false;
        }

        // 3. Risk Evaluation: Margin Sufficiency Test
        // 상황: FreeMargin=10000, Required=5000 -> Success
        if(CXRiskEvaluator::IsMarginSufficient(GetPointer(xp), GetPointer(ctx), 5000.0)) {
            Print("  [PASS] Margin Sufficiency (Normal) Success.");
        } else {
            Print("  [FAIL] Margin Sufficiency (Normal) Failed.");
            allPassed = false;
        }

        // 상황: FreeMargin=10000, Required=15000 -> Fail
        if(!CXRiskEvaluator::IsMarginSufficient(GetPointer(xp), GetPointer(ctx), 15000.0)) {
            Print("  [PASS] Margin Insufficiency (Over) correctly detected.");
        } else {
            Print("  [FAIL] Margin Insufficiency (Over) NOT detected.");
            allPassed = false;
        }

        if(allPassed) Print("--- TestPriceRiskSubdivision: ALL PASSED ---");
        else Print("--- TestPriceRiskSubdivision: SOME TESTS FAILED ---");

        return allPassed;
    }
};

#endif
