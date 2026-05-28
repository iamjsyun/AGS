#ifndef ITRADINGSESSIONCONTEXT_MQH
#define ITRADINGSESSIONCONTEXT_MQH

#include "ICXContext.mqh"

class ICXSignal;

class ITradingSessionContext : public ICXContext {
public:
    virtual ICXSignal* GetBoundSignal() = 0;
};

#endif
