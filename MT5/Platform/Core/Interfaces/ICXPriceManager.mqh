#ifndef ICXPRICEMANAGER_MQH
#define ICXPRICEMANAGER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"

/**
 * @interface ICXPriceManager
 * @brief 가격 계산 및 변환 전문 인터페이스 (SSOC: Single Source of Calculation)
 */
class ICXPriceManager : public CObject {
public:
    virtual ~ICXPriceManager() {}

    //-- 시장가 및 기본 포인트 변환
    virtual double GetMarketPrice(string symbol, int dir) = 0;
    virtual double GetLiquidationPrice(string symbol, int dir) = 0;
    virtual double PointsToPrice(string symbol, int points) = 0;

    //-- [핵심] 오더 실행가 계산 (시장가 +/- 오프셋)
    virtual double CalculateExecPrice(ICXParam* xp, string symbol, int dir, int type, double offsetPts) = 0;

    //-- [핵심] 실행가 기준 SL/TP 계산 (BasePrice +/- 오프셋)
    virtual double CalculateSL(ICXParam* xp, string symbol, int dir, double basePrice, double slPts) = 0;
    virtual double CalculateTP(ICXParam* xp, string symbol, int dir, double basePrice, double tpPts) = 0;
};

#endif
