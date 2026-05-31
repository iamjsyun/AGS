#ifndef CXORDERVALIDATOR_MQH
#define CXORDERVALIDATOR_MQH

#include "..\..\..\01_Core\Interfaces\ICXOrderValidator.mqh"
#include "..\..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXOrderValidator
 * @brief [v1.0] 브로커 거절 방지를 위한 가격 및 거리 보정 로직 (Subdivision Phase 1)
 */
class CXOrderValidator : public ICXOrderValidator {
private:
    ICXContext* m_ctx;

public:
    CXOrderValidator(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXOrderValidator() override {}

    /**
     * @brief [SSOC] StopsLevel 기반 진입 가격 자동 보정
     */
    virtual double ValidateExecPrice(ICXParam* xp, string symbol, int dir, int type, double requestedPrice) override {
        if(type == ORDER_MARKET) return requestedPrice;

        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        ICXPriceManager* priceMgr = CX_GET_OBJ(m_ctx, "price_mgr", ICXPriceManager);
        
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        double currentMkt = IS_VALID(priceMgr) ? priceMgr.GetMarketPrice(symbol, dir) : SymbolInfoDouble(symbol, (dir == CX_DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);
        int stopsLevel = IS_VALID(symMgr) ? symMgr.GetStopsLevel(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        
        // 안전 마진을 위해 stopsLevel + 1 사용 (10015 에러 방어)
        double minDistance = (stopsLevel + 1) * point;
        double validatedPrice = requestedPrice;

        if(dir == CX_DIR_BUY) {
            // Buy Limit은 시장가(Ask)보다 일정 거리 아래에 있어야 함
            double maxAllowed = currentMkt - minDistance;
            if(validatedPrice > maxAllowed) {
                validatedPrice = maxAllowed;
                XP_LOG_WARN(xp, CXAuditFormatter::Build("VALIDATOR-ADJ", xp, StringFormat("Buy Limit price adjusted down to %.5f (Stops:%d)", validatedPrice, stopsLevel)));
            }
        } else {
            // Sell Limit은 시장가(Bid)보다 일정 거리 위에 있어야 함
            double minAllowed = currentMkt + minDistance;
            if(validatedPrice < minAllowed) {
                validatedPrice = minAllowed;
                XP_LOG_WARN(xp, CXAuditFormatter::Build("VALIDATOR-ADJ", xp, StringFormat("Sell Limit price adjusted up to %.5f (Stops:%d)", validatedPrice, stopsLevel)));
            }
        }

        return validatedPrice;
    }

    /**
     * @brief SL/TP 최소 허용 거리 검증 (V11.5 Standard 준수)
     */
    virtual bool ValidateStops(ICXParam* xp, string symbol, int dir, double openPrice, double sl, double tp) override {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double point = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        int stopsLevel = IS_VALID(symMgr) ? symMgr.GetStopsLevel(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minDistance = (stopsLevel + 1) * point;

        if(sl > 0) {
            if(MathAbs(openPrice - sl) < minDistance) {
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("VALIDATOR-FAIL", xp, StringFormat("SL too close. Dist:%.5f, Min:%.5f", MathAbs(openPrice - sl), minDistance)));
                return false;
            }
        }

        if(tp > 0) {
            if(MathAbs(openPrice - tp) < minDistance) {
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("VALIDATOR-FAIL", xp, StringFormat("TP too close. Dist:%.5f, Min:%.5f", MathAbs(openPrice - tp), minDistance)));
                return false;
            }
        }

        return true;
    }
};

#endif
