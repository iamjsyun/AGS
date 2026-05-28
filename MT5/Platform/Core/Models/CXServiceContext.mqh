#ifndef CXSERVICECONTEXT_MQH
#define CXSERVICECONTEXT_MQH

#include "CXContext.mqh"
#include "..\Interfaces\IServiceContext.mqh"

/**
 * @class CXServiceContext
 * @brief Concrete implementation of ServiceContext (Root).
 */
class CXServiceContext : public CXContext {
public:
    CXServiceContext() : CXContext("Service") {}
    virtual ~CXServiceContext() {}

    virtual void Bootstrap() {
        // Global bootstrap logic
    }
};

#endif
