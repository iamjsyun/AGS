#ifndef CXSERVICEFACTORY_MQH
#define CXSERVICEFACTORY_MQH

#include "..\..\Core\Interfaces\ICXServiceFactory.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Logger\CXLogDispatcher.mqh"
#include "..\..\Core\Logger\CXFileLogger.mqh"
#include "..\..\Core\Logger\CXFileLoggerSID.mqh"
#include "..\..\Core\Logger\CXTabLogger.mqh"
#include "..\..\Core\Logger\CXRemoteLogger.mqh"
#include "..\..\Core\Sequence\CXFluentSequence.mqh"
#include "..\..\Core\DB\CXDatabase.mqh"
#include "..\Execution\CXTerminalPlatform.mqh"
#include "..\..\Core\DB\CXSignalRepository.mqh"

#include "..\Execution\CXEntryManager.mqh"
#include "..\Execution\CXOrderManager.mqh"
#include "..\Execution\CXPositionManager.mqh"
#include "..\Execution\CXExitManager.mqh"

#include "..\..\Engine\Price\CXPriceTracker.mqh"
#include "..\..\Engine\Price\CXPriceManager.mqh"
#include "..\..\Engine\Risk\CXRiskManager.mqh"
#include "..\..\Engine\Symbol\CXSymbolManager.mqh"

#include "..\Session\CXSessionTask.mqh"

/**
 * @class CXServiceFactory
 * @brief 구상 클래스의 인스턴스화를 전담하는 팩토리 클래스 (v18.30 expanded)
 */
class CXServiceFactory : public ICXServiceFactory {
public:
    CXServiceFactory() {}
    virtual ~CXServiceFactory() {}

    virtual ICXContext* CreateContext() override {
        return new CXContext();
    }

    virtual ICXLogger* CreateLogger(string sid, ICXConfig* config) override {
        CXLogDispatcher* logger = new CXLogDispatcher();
        if(IS_INVALID(logger)) return NULL;
        logger.SetConfig(config);

        string category = "Session";
        if(StringFind(sid, "Watcher") >= 0) category = "Watcher";
        else if(StringFind(sid, "System") >= 0) category = "System";

        if(IS_VALID(config)) {
            if(config.IsFileLogEnabled(category)) {
                bool initOnStart = true; // [v11.5 Mandate] Always truncate on startup
                if(category == "Session") {
                    CXFileLoggerSID* fileLog = new CXFileLoggerSID();
                    if(IS_VALID(fileLog) && fileLog.Init(sid, initOnStart)) logger.SetFileLogger(fileLog);
                    else SAFE_DELETE(fileLog);
                } else {
                    CXFileLogger* fileLog = new CXFileLogger();
                    if(IS_VALID(fileLog) && fileLog.Init(sid, initOnStart)) logger.SetFileLogger(fileLog);
                    else SAFE_DELETE(fileLog);
                }
            }
            logger.SetTabLogger(new CXTabLogger());
            if(config.IsRemoteLogEnabled(category)) {
                string host = config.GetRemoteLogHost(); int port = config.GetRemoteLogPort();
                if(host != "" && port > 0) logger.SetRemoteLogger(new CXRemoteLogger(sid, host, port, logger.GetFileLogger()));
            }
        }
        return logger;
    }

    virtual ICXFluentSequence* CreateSequence(ICXContext* ctx, string name) override {
        return new CXFluentSequence(ctx, name);
    }

    virtual ICXTradingSession* CreateSession(ICXParam* xp) override {
        if(IS_INVALID(xp)) return NULL;
        ICXSignal* sig = xp.GetSignal();
        ICXContext* ctx = xp.GetContext();
        if(IS_INVALID(sig) || IS_INVALID(ctx)) return NULL;

        return new CXSessionTask(ctx, sig);
    }

    virtual IDatabase* CreateDatabase() override { return new CXDatabase(); }
    virtual IRepository* CreateRepository(IDatabase* db) override { return new CXSignalRepository(db); }
    virtual IXTerminalPlatform* CreateTerminalPlatform(ICXContext* ctx) override { return new CXTerminalPlatform(ctx); }
    virtual IXEntryManager* CreateEntryManager(ICXContext* ctx) override { return new CXEntryManager(ctx); }
    virtual IXOrderManager* CreateOrderManager(ICXContext* ctx) override { return new CXOrderManager(ctx); }
    virtual IXPositionManager* CreatePositionManager(ICXContext* ctx) override { return new CXPositionManager(ctx); }
    virtual IXExitManager* CreateExitManager(ICXContext* ctx) override { return new CXExitManager(ctx); }
    virtual IXPriceTracker* CreatePriceTracker(ICXContext* ctx) override { return new CXPriceTracker(); }
    virtual ICXPriceManager* CreatePriceManager(ICXContext* ctx) override { return new CXPriceManager(ctx); }
    virtual ICXRiskManager* CreateRiskManager(ICXContext* ctx) override { return new CXRiskManager(ctx); }
    virtual ICXSymbolManager* CreateSymbolManager(ICXContext* ctx) override { return new CXSymbolManager(); }
};

#endif
