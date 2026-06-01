#ifndef CXSERVICEFACTORY_MQH
#define CXSERVICEFACTORY_MQH

#include "..\..\01_Core\Interfaces\ICXServiceFactory.mqh"
#include "..\..\02_Domain\Models\CXContext.mqh"
#include "..\..\01_Core\Logger\CXLogDispatcher.mqh"
#include "..\..\01_Core\Logger\CXFileLogger.mqh"
#include "..\..\01_Core\Logger\CXFileLoggerSID.mqh"
#include "..\..\01_Core\Logger\CXTabLogger.mqh"
#include "..\..\01_Core\Logger\CXRemoteLogger.mqh"
#include "..\..\06_Orchestration\Sequence\CXFluentSequence.mqh"
#include "..\..\01_Core\DB\CXDatabase.mqh"
#include "..\..\03_Platform\Execution\CXTerminalPlatform.mqh"
#include "..\..\01_Core\DB\CXSignalRepository.mqh"

#include "..\..\03_Platform\Execution\CXEntryManager.mqh"
#include "..\..\03_Platform\Execution\CXOrderManager.mqh"
#include "..\..\03_Platform\Execution\CXPositionManager.mqh"
#include "..\..\03_Platform\Execution\CXExitManager.mqh"

#include "..\..\03_Platform\Price\CXPriceTracker.mqh"
#include "..\..\03_Platform\Price\CXPriceManager.mqh"
#include "..\..\03_Platform\Risk\CXRiskManager.mqh"
#include "..\..\03_Platform\Symbol\CXSymbolManager.mqh"

#include "..\..\03_Platform\Session\CXSessionTask.mqh"

/**
 * @class CXServiceFactory
 * @brief Factory class dedicated to instantiating concrete classes (v18.30 expanded)
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

    /**
     * @brief [v1.4 Assembly] Automatic Kernel Assembly
     * Registers all core services into the context, reducing procedural code in AppService.
     */
    virtual bool AssembleKernel(ICXContext* ctx, ICXConfig* cfg) override {
        if(IS_INVALID(ctx) || IS_INVALID(cfg)) return false;

        // 0. Register Factory for downstream service creation
        ctx.Register("factory", GetPointer(this), false);

        // 1. Core System Services
        ctx.Register("config", cfg, false);

        ICXLogger* logger = CreateLogger("System", cfg);
        ctx.Register("logger", logger, true);
        ctx.Register("global_logger", logger, false);

        AppOrchestrator* orch = new AppOrchestrator();
        ctx.Register("orchestrator", orch, true);

        CXGuard* guard = new CXGuard(ctx);
        ctx.Register("guard", guard, true);

        // 2. Data Persistence Layer
        IDatabase* db = CreateDatabase();
        if(IS_INVALID(db) || !db.Open(cfg.GetDatabaseName(), cfg.IsDatabaseCommon())) {
            SAFE_DELETE(db);
            return false;
        }
        ctx.Register("db", db, true);

        // Link database to logger dispatcher if applicable
        CXLogDispatcher* dispatcher = dynamic_cast<CXLogDispatcher*>(logger);
        if(IS_VALID(dispatcher)) dispatcher.SetDatabase(db);

        IRepository* repo = CreateRepository(db);
        ctx.Register("repo", repo, true);

        // 3. Platform & Management Layer
        IXTerminalPlatform* terminal = CreateTerminalPlatform(ctx);
        ctx.Register("terminal_platform", terminal, true);

        ctx.Register("sym_mgr",   CreateSymbolManager(ctx),   true);
        ctx.Register("price_mgr", CreatePriceManager(ctx),    true);
        ctx.Register("risk_mgr",  CreateRiskManager(ctx),     true);
        
        ctx.Register("exit_mgr",  CreateExitManager(ctx),     false); // Managed by AppService (Legacy support)
        ctx.Register("order_mgr", CreateOrderManager(ctx),    false);
        ctx.Register("pos_mgr",   CreatePositionManager(ctx), false);

        // 4. Asset Management (Requires Repo & Context)
        CXAssetManager* assetMgr = new CXAssetManager();
        assetMgr.Initialize(repo, ctx, GetPointer(this));
        ctx.Register("asset_mgr", assetMgr, true);

        return true;
    }

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
