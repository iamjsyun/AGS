#ifndef TEST_TICK_SCRAPER_MQH
#define TEST_TICK_SCRAPER_MQH

#include "..\..\..\03_Platform\Internal\Price\CXTickScraper.mqh"

/**
 * @class TestTickScraper
 * @brief CXTickScraper atomic unit test (Hyper-Atomization)
 */
class TestTickScraper {
public:
    static bool Run() {
        Print("--- Running TestTickScraper (Atomic) ---");
        bool allPassed = true;

        // 1. General 0.01 unit normalization (GOLD, etc.)
        double res1 = CXTickScraper::Scrape(2000.1234, 0.01, 2);
        if(res1 == 2000.12) {
            Print("  [PASS] Standard 0.01 Scrape Success.");
        } else {
            PrintFormat("  [FAIL] Standard 0.01 Scrape Failed. Got: %.5f", res1);
            allPassed = false;
        }

        // 2. Specialty 0.25 unit normalization (Futures, etc.)
        // 2000.10 -> 2000.00, 2000.13 -> 2000.25 (MathRound basis)
        double res2 = CXTickScraper::Scrape(2000.13, 0.25, 2);
        if(res2 == 2000.25) {
            Print("  [PASS] Specialty 0.25 Scrape Success.");
        } else {
            PrintFormat("  [FAIL] Specialty 0.25 Scrape Failed. Got: %.5f", res2);
            allPassed = false;
        }

        // 3. 0.00001 unit (FX, etc.)
        double res3 = CXTickScraper::Scrape(1.085427, 0.00001, 5);
        double expectedFX = NormalizeDouble(1.08543, 5);
        if(MathAbs(res3 - expectedFX) < 0.0000001) {
            Print("  [PASS] FX 0.00001 Scrape Success.");
        } else {
            PrintFormat("  [FAIL] FX 0.00001 Scrape Failed. Got: %.6f, Expected: %.6f", res3, expectedFX);
            allPassed = false;
        }

        if(allPassed) Print("--- TestTickScraper: ALL PASSED ---");
        return allPassed;
    }
};

#endif
