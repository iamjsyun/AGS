#ifndef TEST_PRICE_INVERTER_MQH
#define TEST_PRICE_INVERTER_MQH

#include "..\..\..\03_Platform\Internal\Price\CXPriceInverter.mqh"

/**
 * @class TestPriceInverter
 * @brief CXPriceInverter 원자 단위 테스트 (Hyper-Atomization)
 */
class TestPriceInverter {
public:
    static bool Run() {
        Print("--- Running TestPriceInverter (Atomic) ---");
        bool allPassed = true;

        double base = 2000.00;
        double point = 0.01;

        // 1. Buy Offset Test (Price improved when moving down)
        double buyOff = CXPriceInverter::ApplyOffset(base, point, CX_DIR_BUY, 100); // 2000 - 1.0 = 1999.0
        if(buyOff == 1999.0) {
            Print("  [PASS] Buy Offset Success.");
        } else {
            PrintFormat("  [FAIL] Buy Offset Failed. Got: %.5f", buyOff);
            allPassed = false;
        }

        // 2. Sell Offset Test (Price improved when moving up)
        double sellOff = CXPriceInverter::ApplyOffset(base, point, CX_DIR_SELL, 100); // 2000 + 1.0 = 2001.0
        if(sellOff == 2001.0) {
            Print("  [PASS] Sell Offset Success.");
        } else {
            PrintFormat("  [FAIL] Sell Offset Failed. Got: %.5f", sellOff);
            allPassed = false;
        }

        // 3. Profit Direction Test
        double buyProfit = CXPriceInverter::ApplyProfit(base, point, CX_DIR_BUY, 500); // 2000 + 5.0 = 2005.0
        if(buyProfit == 2005.0) {
            Print("  [PASS] Buy Profit Success.");
        } else {
            PrintFormat("  [FAIL] Buy Profit Failed. Got: %.5f", buyProfit);
            allPassed = false;
        }

        if(allPassed) Print("--- TestPriceInverter: ALL PASSED ---");
        return allPassed;
    }
};

#endif
