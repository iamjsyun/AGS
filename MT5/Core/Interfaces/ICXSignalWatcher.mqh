#ifndef ICXSIGNALWATCHER_MQH
#define ICXSIGNALWATCHER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"

class ICXSignalWatcher : public CObject {
public:
    virtual ~ICXSignalWatcher() {}
    virtual void Pulse(ICXParam* xp) = 0;
};

#endif
