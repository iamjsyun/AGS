#ifndef TEST_LOT_STEP_ALIGNER_MQH
#define TEST_LOT_STEP_ALIGNER_MQH

#include "..\..\..\03_Platform\Internal\Risk\CXLotStepAligner.mqh"

/**
 * @class TestLotStepAligner
 * @brief CXLotStepAligner 원자 단위 테스트 (Hyper-Atomization)
 */
class TestLotStepAligner {
public:
    static bool Run() {
        Print("--- Running TestLotStepAligner (Atomic) ---");
        bool allPassed = true;

        // 1. 표준 0.01 스텝 정렬
        double res1 = CXLotStepAligner::Align(0.1234, 0.01, 0.01);
        if(res1 == 0.12) {
            Print("  [PASS] Standard 0.01 Align Success.");
        } else {
            PrintFormat("  [FAIL] Standard 0.01 Align Failed. Got: %.2f", res1);
            allPassed = false;
        }

        // 2. 0.1 스텝 정렬
        double res2 = CXLotStepAligner::Align(0.58, 0.1, 0.1);
        if(res2 == 0.5) {
            Print("  [PASS] Standard 0.1 Align Success.");
        } else {
            PrintFormat("  [FAIL] Standard 0.1 Align Failed. Got: %.1f", res2);
            allPassed = false;
        }

        // 3. 최소 로트 미달 테스트
        double res3 = CXLotStepAligner::Align(0.005, 0.01, 0.01);
        if(res3 == 0.0) {
            Print("  [PASS] Under MinLot correctly handled.");
        } else {
            PrintFormat("  [FAIL] Under MinLot failed. Got: %.2f", res3);
            allPassed = false;
        }

        if(allPassed) Print("--- TestLotStepAligner: ALL PASSED ---");
        return allPassed;
    }
};

#endif
