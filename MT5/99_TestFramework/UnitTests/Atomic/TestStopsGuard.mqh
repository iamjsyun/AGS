#ifndef TEST_STOPS_GUARD_MQH
#define TEST_STOPS_GUARD_MQH

#include "..\..\..\03_Platform\Internal\Order\CXStopsGuard.mqh"

/**
 * @class TestStopsGuard
 * @brief CXStopsGuard 원자 단위 테스트 (Hyper-Atomization)
 */
class TestStopsGuard {
public:
    static bool Run() {
        Print("--- Running TestStopsGuard (Atomic) ---");
        bool allPassed = true;

        // 1. 거리 안전 검증 (Distance Safe)
        // 2000.50 vs 2000.00, MinDist 0.40 -> Safe
        if(CXStopsGuard::IsDistanceSafe(2000.50, 2000.00, 0.40)) {
            Print("  [PASS] Distance Safe Success.");
        } else {
            Print("  [FAIL] Distance Safe Failed.");
            allPassed = false;
        }

        // 2. 거리 위험 검증 (Distance Violation)
        // 2000.10 vs 2000.00, MinDist 0.20 -> Unsafe
        if(!CXStopsGuard::IsDistanceSafe(2000.10, 2000.00, 0.20)) {
            Print("  [PASS] Distance Violation correctly detected.");
        } else {
            Print("  [FAIL] Distance Violation NOT detected.");
            allPassed = false;
        }

        // 3. 진입가(Limit) 위반 검증
        // Ask 2000.50, Buy Limit 2000.45, MinDist 0.10 -> Unsafe (Too close to Ask)
        if(!CXStopsGuard::IsLimitValid(2000.50, 2000.45, 1, 0.10)) {
            Print("  [PASS] Buy Limit proximity violation detected.");
        } else {
            Print("  [FAIL] Buy Limit proximity violation NOT detected.");
            allPassed = false;
        }

        if(allPassed) Print("--- TestStopsGuard: ALL PASSED ---");
        return allPassed;
    }
};

#endif
