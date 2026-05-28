#ifndef CXSYMBOLMANAGER_MQH
#define CXSYMBOLMANAGER_MQH

#include "..\..\Core\Interfaces\ICXSymbolManager.mqh"
#include <Arrays\ArrayString.mqh>

/**
 * @struct SymbolCache
 * @brief 심볼별 명세 데이터를 보관하는 내부 캐시 구조체
 */
struct SymbolCache {
    string symbol;
    double point;
    int    digits;
    double tickSize;
    int    stopsLevel;
    int    freezeLevel;
    double minLot;
    double maxLot;
    double lotStep;
    int    spread;
    datetime lastUpdate;
};

/**
 * @class CXSymbolManager
 * @brief 심볼 명세 캐싱 및 관리 구현체
 */
class CXSymbolManager : public ICXSymbolManager {
private:
    SymbolCache m_cache; // 현재는 단일 심볼(세션 전용) 최적화

public:
    CXSymbolManager() {
        ZeroMemory(m_cache);
    }
    virtual ~CXSymbolManager() {}

    virtual void Refresh(string symbol) override {
        if(m_cache.symbol != symbol || TimeCurrent() - m_cache.lastUpdate > 0) {
            m_cache.symbol      = symbol;
            m_cache.point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
            m_cache.digits      = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            m_cache.tickSize    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            m_cache.stopsLevel  = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            m_cache.freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
            m_cache.minLot      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            m_cache.maxLot      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            m_cache.lotStep     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
            m_cache.spread      = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
            m_cache.lastUpdate  = TimeCurrent();
        }
    }

    virtual double GetPoint(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.point;
    }

    virtual int GetDigits(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.digits;
    }

    virtual double GetTickSize(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.tickSize;
    }

    virtual int GetStopsLevel(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.stopsLevel;
    }

    virtual int GetFreezeLevel(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.freezeLevel;
    }

    virtual double GetMinLot(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.minLot;
    }

    virtual double GetMaxLot(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.maxLot;
    }

    virtual double GetLotStep(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.lotStep;
    }

    virtual int GetSpread(string symbol) override {
        if(m_cache.symbol != symbol) Refresh(symbol);
        return m_cache.spread;
    }
};

#endif
