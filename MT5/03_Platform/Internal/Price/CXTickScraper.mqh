#ifndef CXTICKSCRAPER_MQH
#define CXTICKSCRAPER_MQH

#include <Object.mqh>

/**
 * @class CXTickScraper
 * @brief [v1.0] TickSize 및 Digits 기반 가격 반올림/절사 전문 원자 클래스 (Hyper-Atomization)
 * @details MT5 API에 의존하지 않는 순수 수학 로직만 보유함
 */
class CXTickScraper : public CObject {
public:
    /**
     * @brief 소수점 및 호가 단위(TickSize)에 맞게 가격 보정
     * @param price 원본 가격
     * @param tickSize 호가 단위 (예: 0.01)
     * @param digits 소수점 자리수 (예: 2)
     */
    static double Scrape(double price, double tickSize, int digits) {
        if(price <= 0) return 0;
        if(tickSize <= 0) return NormalizeDouble(price, digits);
        
        // MathRound를 통해 가장 가까운 호가 단위로 정렬 후 소수점 정규화
        double steps = MathRound(price / tickSize);
        return NormalizeDouble(steps * tickSize, digits);
    }
};

#endif
