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
 * @brief [v18.31] 터미널 물리 자산의 실존 보증, 인벤토리 동기화 및 원자적 집행을 총괄하는 인터페이스 (Asset-Centric)
 */
class ICXAssetManager : public CObject {
public:
    virtual ~ICXAssetManager() {}
    virtual void Initialize(IRepository* repo, ICXContext* ctx, ICXServiceFactory* factory) = 0;
    
    // 1. 진입/청산 집행 (Commands)
    virtual ulong ExecuteEntry(ICXParam* xp) = 0; 
    virtual bool  ExecuteExit(ICXParam* xp, string sid) = 0; 
    
    // 2. 물리 자산 조회 및 보증 (Queries)
    virtual bool  IsAssetLive(string sid) = 0;
    virtual bool  IsPositionExists(ulong ticket) = 0;
    virtual bool  IsOrderExists(ulong ticket) = 0;
    virtual bool  IsAssetExists(ulong ticket, int type) = 0;

    // 3. 인벤토리 데이터 동기화 (Inventory SSOC)
    virtual bool  SyncToSignal(ICXSignal* sig) = 0;
    virtual int   CheckHistoryClosure(ulong ticket, string &reason) = 0;
    virtual double GetCurrentVolume(ulong ticket, bool isPosition) = 0;
    virtual double GetCurrentPriceOpen(ulong ticket, bool isPosition) = 0;
    virtual double GetCurrentSL(ulong ticket) = 0;
    virtual double GetCurrentTP(ulong ticket) = 0;
    virtual double GetCurrentProfit(ulong ticket) = 0;
    
    // 4. 세션 관리 (Tasks)
    virtual ICXTradingSession* CreateSession(ICXParam* xp) = 0;
    virtual ICXTradingSession* FindSessionBySid(const string sid) = 0;
    
    // 5. 관리 루프 (Sync & Task Pulse)
    virtual void  Pulse(ICXParam* xp) = 0;
};

#endif
