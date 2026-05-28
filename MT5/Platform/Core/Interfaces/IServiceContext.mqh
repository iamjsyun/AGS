#ifndef ISERVICECONTEXT_MQH
#define ISERVICECONTEXT_MQH

#include "ICXContext.mqh"

class IServiceContext : public ICXContext {
public:
    virtual void Bootstrap() = 0;
};

#endif
