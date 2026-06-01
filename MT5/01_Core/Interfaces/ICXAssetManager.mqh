#ifndef ICXASSETMANAGER_MQH
#define ICXASSETMANAGER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXTradingSession.mqh"
#include "IRepository.mqh"
#include "ICXServiceFactory.mqh"
#include "ICXContext.mqh"

/**
 * @class ICXAssetManager
 * @brief [v18.31] Interface managing terminal physical assets, ensuring data synchronization and atomic execution (Asset-Centric)
 */
class ICXAssetManager : public CObject {
public:
    virtual ~ICXAssetManager() {}
    virtual void Initialize(IRepository* repo, ICXContext* ctx, ICXServiceFactory* factory) = 0;
    
    // 1. Execution Commands
    virtual ulong ExecuteEntry(ICXParam* xp) = 0; 
    virtual bool  ExecuteExit(ICXParam* xp, string sid) = 0; 
    
    // 2. Physical Asset Queries
    virtual bool  IsAssetLive(string sid) = 0;
    virtual bool  IsPositionExists(ulong ticket) = 0;
    virtual bool  IsOrderExists(ulong ticket) = 0;
    virtual bool  IsAssetExists(ulong ticket, int type) = 0;

    // 3. Asset Data Synchronization (Asset SSOC)
    virtual bool  SyncToSignal(ICXSignal* sig) = 0;
    virtual int   CheckHistoryClosure(ulong ticket, string &reason) = 0;
    virtual double GetCurrentVolume(ulong ticket, bool isPosition) = 0;
    virtual double GetCurrentPriceOpen(ulong ticket, bool isPosition) = 0;
    virtual double GetCurrentSL(ulong ticket) = 0;
    virtual double GetCurrentTP(ulong ticket) = 0;
    virtual double GetCurrentProfit(ulong ticket) = 0;
    
    // 4. Session Management Tasks
    virtual ICXTradingSession* CreateSession(ICXParam* xp) = 0;
    virtual ICXTradingSession* FindSessionBySid(const string sid) = 0;
    
    // 5. Management Loops (Sync & Task Pulse)
    virtual void  Pulse(ICXParam* xp) = 0;
};

#endif
