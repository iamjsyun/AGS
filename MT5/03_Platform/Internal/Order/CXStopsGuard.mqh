#ifndef CXSTOPSGUARD_MQH
#define CXSTOPSGUARD_MQH

#include <Object.mqh>

/**
 * @class CXStopsGuard
 * @brief [v1.0] 최소 허용 거리(StopsLevel) 준수 여부 전담 원자 클래스 (Hyper-Atomization)
 */
class CXStopsGuard : public CObject {
public:
    /**
     * @brief 두 가격 사이의 거리가 최소 허용치를 충족하는지 검증
     * @param price1 기준가
     * @param price2 대상가 (SL, TP 등)
     * @param minDistance 최소 허용 거리 (Price 단위)
     * @return 충분한 거리면 true
     */
    static bool IsDistanceSafe(double price1, double price2, double minDistance) {
        if(price2 <= 0) return true; // 설정 안됨은 통과
        return (MathAbs(price1 - price2) >= minDistance - 0.0000001);
    }

    /**
     * @brief 시장가 대비 진입 제한가(Limit)의 유효성 검증
     * @param marketPrice 현재 시장가
     * @param limitPrice 진입 제한가
     * @param dir 매수(1)/매도(-1)
     * @param minDistance 최소 허용 거리
     */
    static bool IsLimitValid(double marketPrice, double limitPrice, int dir, double minDistance) {
        if(dir == 1) { // CX_DIR_BUY
            // Buy Limit은 시장가(Ask)보다 낮아야 함
            return (limitPrice <= marketPrice - minDistance + 0.0000001);
        } else { // CX_DIR_SELL
            // Sell Limit은 시장가(Bid)보다 높아야 함
            return (limitPrice >= marketPrice + minDistance - 0.0000001);
        }
    }
};

#endif
