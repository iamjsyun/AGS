#ifndef CXPRICENORMALIZER_MQH
#define CXPRICENORMALIZER_MQH

#include <Object.mqh>
#include "..\..\..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"

/**
 * @class CXPriceNormalizer
 * @brief [v1.0] Class dedicated to price normalization based on TickSize and Digits (Subdivision Phase 1)
 */
class CXPriceNormalizer : public CObject {
public:
    /**
     * @brief Adjust price according to decimal places and tick size
     */
    static double Normalize(ICXContext* ctx, string symbol, double price) {
        if(price <= 0) return 0;
        
        ICXSymbolManager* symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
        double tickSize = IS_VALID(symMgr) ? symMgr.GetTickSize(symbol) : SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        int    digits   = IS_VALID(symMgr) ? symMgr.GetDigits(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        if(tickSize <= 0) return NormalizeDouble(price, digits);
        return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
    }
};

#endif
