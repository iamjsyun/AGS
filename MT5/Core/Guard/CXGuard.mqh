#ifndef CXGUARD_MQH
#define CXGUARD_MQH

#include "..\Interfaces\IXGuard.mqh"
#include "..\Interfaces\ICXConfig.mqh"
#include "..\Interfaces\ICXContext.mqh"
#include "..\Interfaces\ICXSymbolManager.mqh"
#include "..\Defines\CXDefine.mqh"

class CXGuard : public IXGuard {
private:
    ICXContext* m_ctx;
    string m_lastError;

    bool SetError(string msg) { m_lastError = msg; return false; }

public:
    CXGuard(ICXContext* ctx) : m_ctx(ctx) { m_lastError = ""; }
    virtual ~CXGuard() {}

    // Identification Validation
    virtual bool ValidateMagic(long magic) {
        ICXConfig* config = CX_GET_OBJ(m_ctx, "config", ICXConfig);
        if(IS_INVALID(config)) return SetError("Config not found for Magic validation");
        if(!config.IsTargetMagic(magic)) return SetError("Magic Number " + IntegerToString(magic) + " is not registered");
        return true;
    }

    virtual bool ValidateSID(string sid) {
        if(StringLen(sid) != SID_MAX_LENGTH) return SetError("Invalid SID length: " + sid);
        return true;
    }

    virtual bool ValidateGID(string gid) {
        if(StringLen(gid) != GID_MAX_LENGTH) return SetError("Invalid GID length: " + gid);
        return true;
    }

    // Trading Metric Validation
    virtual bool ValidatePrice(string symbol, double price) {
        if(price <= 0) return SetError("Price must be positive");
        double min_p = SymbolInfoDouble(symbol, SYMBOL_SESSION_PRICE_LIMIT_MIN);
        double max_p = SymbolInfoDouble(symbol, SYMBOL_SESSION_PRICE_LIMIT_MAX);
        if(min_p > 0 && price < min_p) return SetError("Price below limit: " + DoubleToString(min_p, 5));
        if(max_p > 0 && price > max_p) return SetError("Price above limit: " + DoubleToString(max_p, 5));
        return true;
    }

    virtual bool ValidateLot(string symbol, double lot) {
        if(symbol == "" || symbol == "NULL") return SetError("Symbol is empty");
        
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double min_v = IS_VALID(symMgr) ? symMgr.GetMinLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double max_v = IS_VALID(symMgr) ? symMgr.GetMaxLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        
        //-- [Fix] SYMBOL_VOLUME_MAX가 0인 경우 (심볼 미로드 또는 시장 미참여)
        if(max_v <= 0) {
            if(!SymbolSelect(symbol, true)) return SetError("Symbol " + symbol + " not found in Market Watch");
            if(IS_VALID(symMgr)) symMgr.Refresh(symbol);
            min_v = IS_VALID(symMgr) ? symMgr.GetMinLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            max_v = IS_VALID(symMgr) ? symMgr.GetMaxLot(symbol) : SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            if(max_v <= 0) return SetError(StringFormat("Symbol property error (%s). Max lot is 0.00", symbol));
        }

        if(lot < min_v) return SetError(StringFormat("Lot(%.2f) below minimum(%.2f) for %s", lot, min_v, symbol));
        if(lot > max_v) return SetError(StringFormat("Lot(%.2f) above maximum(%.2f) for %s", lot, max_v, symbol));
        return true;
    }

    virtual bool ValidateSlippage(int slippage) {
        if(slippage < 0 || slippage > MAX_SLIPPAGE) return SetError("Slippage out of range");
        return true;
    }
    
    // Price & Point Processing
    virtual double PointsToPrice(string symbol, double points) const {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double pt = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        return points * pt;
    }

    virtual double NormalizePrice(string symbol, double price) const {
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        int digits = IS_VALID(symMgr) ? symMgr.GetDigits(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        return NormalizeDouble(price, digits);
    }

    virtual bool ValidateStopLevel(string symbol, double base_price, double target_price) {
        if(target_price <= 0) return true; // Ignore if not set
        
        ICXSymbolManager* symMgr = CX_GET_OBJ(m_ctx, "sym_mgr", ICXSymbolManager);
        double pt = IS_VALID(symMgr) ? symMgr.GetPoint(symbol) : SymbolInfoDouble(symbol, SYMBOL_POINT);
        int stops = IS_VALID(symMgr) ? symMgr.GetStopsLevel(symbol) : (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double stops_lvl = (stops + 1) * pt;
        double diff = MathAbs(base_price - target_price);
        
        if(diff < stops_lvl) {
            return SetError(StringFormat("Distance too small (StopsLevel+1: %.5f, Current: %.5f)", stops_lvl, diff));
        }
        return true;
    }

    // String & Protocol Validation
    virtual bool ValidateComment(string comment) {
        if(StringLen(comment) > COMMENT_MAX_LENGTH) return SetError("Comment too long");
        return true;
    }

    virtual bool ValidateCnoBinding(int cno, long magic) {
        if((long)cno != magic) return SetError("CNO-Magic Mismatch");
        return true;
    }
    
    virtual string GetLastError() const { return m_lastError; }
    
    virtual bool Check(ICXParam* xp, ICXContext* ctx) {
        if(IS_INVALID(xp)) return true;
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return true;
        
        if(!ValidateMagic(sig.GetMagic())) return false;
        if(!ValidateSID(sig.GetSid())) return false;
        
        return true;
    }
};

#endif
