#ifndef ICXORDERVALIDATOR_MQH
#define ICXORDERVALIDATOR_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXSignal.mqh"

/**
 * @interface ICXOrderValidator
 * @brief [v1.0] 주문 전송 전 가격 및 거리(StopsLevel) 무결성 검증 인터페이스
 */
class ICXOrderValidator : public CObject {
public:
    virtual ~ICXOrderValidator() {}
    
    /**
     * @brief 요청된 진입 가격이 브로커의 최소 거리(StopsLevel)를 준수하는지 검증하고 필요 시 보정함
     */
    virtual double ValidateExecPrice(ICXParam* xp, string symbol, int dir, int type, double requestedPrice) = 0;

    /**
     * @brief SL/TP 가격이 최소 허용 거리를 충족하는지 검증
     */
    virtual bool ValidateStops(ICXParam* xp, string symbol, int dir, double openPrice, double sl, double tp) = 0;
};

#endif
