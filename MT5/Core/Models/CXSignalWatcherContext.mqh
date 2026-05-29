#ifndef CXSIGNALWATCHERCONTEXT_MQH
#define CXSIGNALWATCHERCONTEXT_MQH

#include "CXContext.mqh"
#include "..\Interfaces\ISignalWatcherContext.mqh"
#include "..\Macros\CXMacros.mqh"

/**
 * @class CXSignalWatcherContext
 * @brief Concrete implementation of SignalWatcherContext (Detection).
 */
class CXSignalWatcherContext : public CXContext {
public:
    CXSignalWatcherContext() : CXContext("Watcher") {}
    virtual ~CXSignalWatcherContext() {}

    virtual CArrayObj* GetActiveSignals() override {
        return CX_GET_OBJ(this, "active_signals", CArrayObj);
    }
};

#endif
