#ifndef ICXSERVICEFACTORY_MQH
#define ICXSERVICEFACTORY_MQH

#include <Object.mqh>
#include "ICXContext.mqh"
#include "ICXLogger.mqh"
#include "ICXFluentSequence.mqh"
#include "ICXTradingSession.mqh"
#include "IXEntryManager.mqh"
#include "IXOrderManager.mqh"
#include "IXPositionManager.mqh"
#include "IXExitManager.mqh"
#include "IXPriceTracker.mqh"
#include "ICXPriceManager.mqh"
#include "IXTerminalPlatform.mqh"

class ICXContext;
class ICXLogger;
class ICXFluentSequence;
class ICXTradingSession;
class ICXConfig;
class IDatabase;
class IRepository;
class IXEntryManager;
class IXOrderManager;
class IXPositionManager;
class IXExitManager;
class IXPriceTracker;
class ICXPriceManager;
class ICXRiskManager;
class ICXSymbolManager;
class IXTerminalPlatform;

/**
 * @class ICXServiceFactory
 * @brief 의존성 주입(DI)을 위한 서비스 팩토리 인터페이스 (v18.30 expanded)
 */
class ICXServiceFactory : public CObject {
public:
    virtual ~ICXServiceFactory() {}
    
    // Core Services
    virtual ICXContext*        CreateContext() = 0;
    virtual ICXLogger*         CreateLogger(string sid, ICXConfig* config) = 0;
    virtual ICXFluentSequence* CreateSequence(ICXContext* ctx, string name) = 0;
    virtual ICXTradingSession* CreateSession(ICXParam* xp) = 0;
    virtual IDatabase*         CreateDatabase() = 0;
    virtual IRepository*       CreateRepository(IDatabase* db) = 0;
    virtual IXTerminalPlatform* CreateTerminalPlatform(ICXContext* ctx) = 0;

    // Managers & Trackers
    virtual IXEntryManager*    CreateEntryManager(ICXContext* ctx) = 0;
    virtual IXOrderManager*    CreateOrderManager(ICXContext* ctx) = 0;
    virtual IXPositionManager* CreatePositionManager(ICXContext* ctx) = 0;
    virtual IXExitManager*     CreateExitManager(ICXContext* ctx) = 0;
    virtual IXPriceTracker*    CreatePriceTracker(ICXContext* ctx) = 0;
    virtual ICXPriceManager*   CreatePriceManager(ICXContext* ctx) = 0;
    virtual ICXRiskManager*    CreateRiskManager(ICXContext* ctx) = 0;
    virtual ICXSymbolManager*  CreateSymbolManager(ICXContext* ctx) = 0;
};
#endif
