#ifndef CXPRICEMANAGER_MQH
#define CXPRICEMANAGER_MQH

#include "..\..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\01_Core\Defines\CXDefine.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\Execution\Platform\CXPriceNormalizer.mqh"

/**
 * @class CXPriceManager
 * @brief Specialized implementation for price calculation and integrity verification (v11.6 Subdivision)
 */
class CXPriceManager : public ICXPriceManager {
private:
    ICXContext* m_ctx;

public:
    CXPriceManager(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXPriceManager() {}
    void SetContext(ICXContext* ctx) { m_ctx = ctx; }

    virtual double GetMarketPrice(string symbol, int dir) override {
        return (dir == CX_DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    }

    virtual double GetLiquidationPrice(string symbol, int dir) override {
        return (dir == CX_DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    }

    virtual double PointsToPrice(string symbol, int points) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        return points * point;
    }

    virtual double CalculateExecPrice(ICXParam* xp, string symbol, int dir, int type, double offsetPts) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double mkt = GetMarketPrice(symbol, dir);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        if(type == ORDER_MARKET) return CXPriceNormalizer::Normalize(m_ctx, symbol, mkt);

        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        double execPrice = CXPriceNormalizer::Normalize(m_ctx, symbol, mkt - (offsetPts * point * dir_sign));

        //--- [v11.5 StopsLevel Guard]
        int stopsLevel = IS_VALID(symMgr) ? symMgr.GetStopsLevel(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minDistance = (stopsLevel + 3) * point;
        
        if(dir == CX_DIR_BUY) {
            double maxAllowed = mkt - minDistance;
            if(execPrice > maxAllowed) execPrice = CXPriceNormalizer::Normalize(m_ctx, symbol, maxAllowed);
        } else {
            double minAllowed = mkt + minDistance;
            if(execPrice < minAllowed) execPrice = CXPriceNormalizer::Normalize(m_ctx, symbol, minAllowed);
        }
        return execPrice;
    }

    virtual double CalculateSL(ICXParam* xp, string symbol, int dir, double basePrice, double slPts) override {
        if(slPts <= 0) return 0;
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        return CXPriceNormalizer::Normalize(m_ctx, symbol, basePrice - (slPts * point * dir_sign));
    }

    virtual double CalculateTP(ICXParam* xp, string symbol, int dir, double basePrice, double tpPts) override {
        if(tpPts <= 0) return 0;
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        return CXPriceNormalizer::Normalize(m_ctx, symbol, basePrice + (tpPts * point * dir_sign));
    }
};

#endif
