#ifndef CXPRICEMANAGER_MQH
#define CXPRICEMANAGER_MQH

#include "..\..\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\Core\Interfaces\ICXContext.mqh"
#include "..\..\Core\Defines\CXDefine.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"

/**
 * @class CXPriceManager
 * @brief 가격 계산 및 무결성 검증 전문 구현체 (v11.5 Standard)
 */
class CXPriceManager : public ICXPriceManager {
private:
    ICXContext* m_ctx;

    /**
     * @brief 심볼의 TickSize에 맞춰 가격을 정규화 (Standard v11.5)
     */
    double NormalizePrice(string symbol, double price) {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double tickSize = IS_VALID(symMgr) ? symMgr.GetTickSize(symbol) : SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        int    digits   = IS_VALID(symMgr) ? symMgr.GetDigits(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        if(tickSize <= 0) return NormalizeDouble(price, digits);
        return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
    }

public:
    CXPriceManager(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXPriceManager() {}
    void SetContext(ICXContext* ctx) { m_ctx = ctx; }

    /**
     * @brief 방향에 따른 실시간 시장가 추출 (Ask/Bid)
     */
    virtual double GetMarketPrice(string symbol, int dir) override {
        double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
        return (dir == CX_DIR_BUY) ? currentAsk : currentBid;
    }

    /**
     * @brief 방향에 따른 청산 가격 추출 (Buy->Bid, Sell->Ask)
     */
    virtual double GetLiquidationPrice(string symbol, int dir) override {
        double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
        return (dir == CX_DIR_BUY) ? currentBid : currentAsk;
    }

    /**
     * @brief 포인트 값을 절대 가격 오프셋으로 변환
     */
    virtual double PointsToPrice(string symbol, int points) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        return points * point;
    }

    /**
     * @brief 오더 실행가 계산 (v11.0: 시장가 기반 동적 산출)
     */
    virtual double CalculateExecPrice(ICXParam* xp, string symbol, int dir, int type, double offsetPts) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double marketPrice = GetMarketPrice(symbol, dir);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        if(type == ORDER_MARKET) return NormalizePrice(symbol, marketPrice);

        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;
        double rawExecPrice = marketPrice - (offsetPts * point * dir_sign);
        double execPrice = NormalizePrice(symbol, rawExecPrice);

        //--- [v11.5 StopsLevel Guard] 브로커의 최소 거리 제한 준수
        int stopsLevel = IS_VALID(symMgr) ? symMgr.GetStopsLevel(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minDistance = (stopsLevel + 3) * point; // [v12.3 Resilience] 안전을 위해 +3 틱 적용 (10015 에러 방지)
        
        if(dir == CX_DIR_BUY) {
            // Buy Limit은 시장가(Ask)보다 아래에 있어야 함
            double maxAllowed = marketPrice - minDistance;
            if(execPrice > maxAllowed) {
                execPrice = NormalizePrice(symbol, maxAllowed);
            }
        } else {
            // Sell Limit은 시장가(Bid)보다 위에 있어야 함
            double minAllowed = marketPrice + minDistance;
            if(execPrice < minAllowed) {
                execPrice = NormalizePrice(symbol, minAllowed);
            }
        }

        // [v12.7 Muted] XP_LOG_TRACE(xp, StringFormat("[PRICE-MGR] ExecPrice: Mkt:%.5f, Off:%.0f pts -> Final:%.5f", marketPrice, offsetPts, execPrice));
        return execPrice;
    }

    /**
     * @brief 실행가 기준 SL 계산
     */
    virtual double CalculateSL(ICXParam* xp, string symbol, int dir, double basePrice, double slPts) override {
        if(slPts <= 0) return 0;
        
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;

        double sl = NormalizePrice(symbol, basePrice - (slPts * point * dir_sign));
        // [v12.7 Muted] XP_LOG_TRACE(xp, StringFormat("[PRICE-MGR] SL: Base:%.5f, Off:%.0f pts -> SL:%.5f", basePrice, slPts, sl));
        return sl;
    }

    /**
     * @brief 실행가 기준 TP 계산
     */
    virtual double CalculateTP(ICXParam* xp, string symbol, int dir, double basePrice, double tpPts) override {
        if(tpPts <= 0) return 0;

        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        double dir_sign = (dir == CX_DIR_BUY) ? 1.0 : -1.0;

        double tp = NormalizePrice(symbol, basePrice + (tpPts * point * dir_sign));
        // [v12.7 Muted] XP_LOG_TRACE(xp, StringFormat("[PRICE-MGR] TP: Base:%.5f, Off:%.0f pts -> TP:%.5f", basePrice, tpPts, tp));
        return tp;
    }
};

#endif
