#ifndef ICXRISKMANAGER_MQH
#define ICXRISKMANAGER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"

/**
 * @interface ICXRiskManager
 * @brief 리스크 및 자금 관리 전문 인터페이스 (SSOC: Risk & Volume Management)
 */
class ICXRiskManager : public CObject {
public:
    virtual ~ICXRiskManager() {}

    //-- 로트(Volume) 유효성 및 보정
    virtual bool   ValidateLot(ICXParam* xp, string symbol, double lot) = 0;
    virtual double NormalizeLot(string symbol, double lot) = 0;
    
    //-- 마진(Margin) 및 잔고 검증
    virtual double CalculateRequiredMargin(string symbol, int dir, double lot, double price) = 0;
    virtual bool   CheckMarginAvailability(ICXParam* xp, string symbol, int dir, double lot, double price) = 0;

    //-- 계좌 리스크 한도 검증 (전체 세션 합산 리스크 등 확장용)
    virtual bool   ValidateAccountRisk(ICXParam* xp) = 0;

    // [v13.4 UAF Standard]
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") = 0;
};

#endif
