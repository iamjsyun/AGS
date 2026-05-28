#ifndef ISIGNALWATCHERCONTEXT_MQH
#define ISIGNALWATCHERCONTEXT_MQH

#include "ICXContext.mqh"
#include <Arrays\ArrayObj.mqh>

class ISignalWatcherContext : public ICXContext {
public:
    virtual CArrayObj* GetActiveSignals() = 0;
};

#endif
