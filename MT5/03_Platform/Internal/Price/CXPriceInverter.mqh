#ifndef CXPRICEINVERTER_MQH
#define CXPRICEINVERTER_MQH

#include <Object.mqh>
#include "..\..\..\01_Core\Defines\CXDefine.mqh"

/**
 * @class CXPriceInverter
 * @brief [v1.0] 매수/매도 방향 및 포인트값에 따른 가격 오프셋 계산 원자 클래스 (Hyper-Atomization)
 */
class CXPriceInverter : public CObject {
public:
    /**
     * @brief 방향에 따른 가격 계산 (Buy는 차감, Sell은 가산하여 진입가 개선 방향 산출)
     */
    static double ApplyOffset(double basePrice, double point, int dir, int points) {
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        return basePrice - (points * point * dir_sign);
    }

    /**
     * @brief 수익 방향 계산 (Buy는 가산, Sell은 차감)
     */
    static double ApplyProfit(double basePrice, double point, int dir, int points) {
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        return basePrice + (points * point * dir_sign);
    }
};

#endif
