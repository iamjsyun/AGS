#ifndef ICXAPPSERVICE_MQH
#define ICXAPPSERVICE_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"
#include "ICXConfig.mqh"
#include "ICXServiceFactory.mqh"

class ICXAppService : public CObject {
public:
    virtual ~ICXAppService() {}

    /**
     * @brief Two-phase Initialization (Detect internal failures)
     */
    virtual bool Initialize(ICXConfig* config, ICXServiceFactory* factory) = 0;
    virtual void Pulse(ENUM_CX_EVENT event = EVENT_TIMER) = 0;
    virtual ICXContext* GetContext() = 0;

    virtual void OnTradeTransaction(const MqlTradeTransaction& trans,
                                    const MqlTradeRequest& request,
                                    const MqlTradeResult& result) = 0;
};

#endif
