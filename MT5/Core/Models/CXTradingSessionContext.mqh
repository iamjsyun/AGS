#ifndef CXTRADINGSESSIONCONTEXT_MQH
#define CXTRADINGSESSIONCONTEXT_MQH

#include "CXContext.mqh"
#include "..\Interfaces\ITradingSessionContext.mqh"
#include "..\Macros\CXMacros.mqh"

/**
 * @class CXTradingSessionContext
 * @brief Concrete implementation of TradingSessionContext (Sandbox).
 */
class CXTradingSessionContext : public CXContext {
public:
    CXTradingSessionContext(string sid) : CXContext(sid) {}
    virtual ~CXTradingSessionContext() {}

    virtual ICXSignal* GetBoundSignal() override {
        return CX_GET_OBJ(this, "sig", ICXSignal);
    }
};

#endif
