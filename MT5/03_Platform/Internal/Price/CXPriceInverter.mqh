#ifndef CXPRICEINVERTER_MQH
#define CXPRICEINVERTER_MQH

#include <Object.mqh>
#include "..\..\..\01_Core\Defines\CXDefine.mqh"

/**
 * @class CXPriceInverter
 * @brief [v1.0] Atomic class for calculating price offsets based on Buy/Sell direction and point value (Hyper-Atomization)
 */
class CXPriceInverter : public CObject {
public:
    /**
     * @brief Calculate price based on direction (Subtract for Buy, Add for Sell to calculate entry price improvement direction)
     */
    static double ApplyOffset(double basePrice, double point, int dir, int points) {
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        return basePrice - (points * point * dir_sign);
    }

    /**
     * @brief Calculate profit direction (Add for Buy, Subtract for Sell)
     */
    static double ApplyProfit(double basePrice, double point, int dir, int points) {
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        return basePrice + (points * point * dir_sign);
    }
};

#endif
