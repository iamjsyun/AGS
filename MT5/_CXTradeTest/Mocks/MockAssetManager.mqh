#ifndef MOCK_ASSET_MANAGER_MQH
#define MOCK_ASSET_MANAGER_MQH

#include "..\..\Core\Interfaces\ICXAssetManager.mqh"

/**
 * @class MockAssetManager
 * @brief ICXAssetManager의 단위 테스트용 Mock 객체
 */
class MockAssetManager : public ICXAssetManager {
private:
    bool m_positionExists;
public:
    MockAssetManager() : m_positionExists(false) {}
    virtual ~MockAssetManager() override {}

    void SetPositionExists(bool exists) { m_positionExists = exists; }

    virtual void Initialize(IRepository* repo, ICXContext* ctx, ICXServiceFactory* factory) override {}
    virtual ulong ExecuteEntry(ICXParam* xp) override { return 0; }
    virtual bool  ExecuteExit(ICXParam* xp, string sid) override { return true; }
    virtual bool  IsAssetLive(string sid) override { return true; }
    virtual bool  IsPositionExists(ulong ticket) override { return m_positionExists; }
    virtual bool  IsOrderExists(ulong ticket) override { return false; }
    virtual bool  IsAssetExists(ulong ticket, int type) override { return m_positionExists; }
    virtual bool  SyncToSignal(ICXSignal* sig) override { return true; }
    virtual int   CheckHistoryClosure(ulong ticket, string &reason) override { return 0; }
    virtual double GetCurrentVolume(ulong ticket, bool isPosition) override { return 0.0; }
    virtual double GetCurrentPriceOpen(ulong ticket, bool isPosition) override { return 0.0; }
    virtual double GetCurrentSL(ulong ticket) override { return 0.0; }
    virtual double GetCurrentTP(ulong ticket) override { return 0.0; }
    virtual double GetCurrentProfit(ulong ticket) override { return 0.0; }
    virtual ICXTradingSession* CreateSession(ICXParam* xp) override { return NULL; }
    virtual ICXTradingSession* FindSessionBySid(const string sid) override { return NULL; }
    virtual void  Pulse(ICXParam* xp) override {}
};

#endif
