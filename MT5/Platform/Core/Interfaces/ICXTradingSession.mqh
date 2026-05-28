#ifndef ICXTRADINGSESSION_MQH
#define ICXTRADINGSESSION_MQH

#include <Object.mqh>
#include "ICXSignal.mqh"
#include "ICXParam.mqh"

/**
 * @class ICXTradingSession
 * @brief [v18.30] 자산 단위 태스크(Unit Task)를 수행하는 세션 인터페이스
 */
class ICXTradingSession : public CObject {
public:
    virtual ~ICXTradingSession() {}
    
    virtual string GetSid() const = 0;
    virtual bool   IsActive() const = 0;
    virtual int    GetState() const = 0;
    virtual ICXSignal* GetSignal() const = 0;

    virtual void   Start(ICXParam* xp) = 0;
    virtual void   Pulse(ICXParam* xp) = 0;
    virtual void   ForceTransition(int state) = 0;
    virtual void   InjectState(ICXSignal* sig) = 0;
};

#endif
