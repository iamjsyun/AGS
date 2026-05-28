#ifndef ICXAUDITPROVIDER_MQH
#define ICXAUDITPROVIDER_MQH

#include "ICXParam.mqh"

/**
 * @interface ICXAuditProvider
 * @brief 자기 자신의 상태를 표준 문자열로 요약하여 제공하는 인터페이스
 */
class ICXAuditProvider {
public:
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") = 0;
};

#endif
