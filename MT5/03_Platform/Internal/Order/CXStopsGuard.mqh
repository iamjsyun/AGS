#ifndef CXSTOPSGUARD_MQH
#define CXSTOPSGUARD_MQH

#include <Object.mqh>

/**
 * @class CXStopsGuard
 * @brief [v1.0] Atomic class dedicated to compliance with minimum allowable distance (StopsLevel) (Hyper-Atomization)
 */
class CXStopsGuard : public CObject {
public:
    /**
     * @brief Verify if the distance between two prices meets the minimum allowance
     * @param price1 Base price
     * @param price2 Target price (SL, TP, etc.)
     * @param minDistance Minimum allowable distance (Price unit)
     * @return true if the distance is sufficient
     */
    static bool IsDistanceSafe(double price1, double price2, double minDistance) {
        if(price2 <= 0) return true; // If not set, pass
        return (MathAbs(price1 - price2) >= minDistance - 0.0000001);
    }

    /**
     * @brief Verify validity of entry limit price relative to market price
     * @param marketPrice Current market price
     * @param limitPrice Entry limit price
     * @param dir Buy(1)/Sell(-1)
     * @param minDistance Minimum allowable distance
     */
    static bool IsLimitValid(double marketPrice, double limitPrice, int dir, double minDistance) {
        if(dir == 1) { // CX_DIR_BUY
            // Buy Limit must be lower than market price (Ask)
            return (limitPrice <= marketPrice - minDistance + 0.0000001);
        } else { // CX_DIR_SELL
            // Sell Limit must be higher than market price (Bid)
            return (limitPrice >= marketPrice + minDistance - 0.0000001);
        }
    }
};

#endif
