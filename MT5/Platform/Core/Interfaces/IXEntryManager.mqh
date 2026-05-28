#ifndef IXENTRYMANAGER_MQH
#define IXENTRYMANAGER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"

/**
 * @class IXEntryManager
 * @brief 진입 전략 및 파라미터 관리를 위한 인터페이스
 */
class IXEntryManager : public CObject {
public:
    virtual void Pulse(ICXParam* xp) = 0;
    virtual int  ValidateTerminalIntegrity(ICXParam* xp) = 0;
};

#endif
