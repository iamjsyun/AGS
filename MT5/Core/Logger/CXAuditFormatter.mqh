#ifndef CXAUDITFORMATTER_MQH
#define CXAUDITFORMATTER_MQH

#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXSignal.mqh"
#include "..\Defines\CXDefine.mqh"

/**
 * @class CXAuditFormatter
 * @brief Universal Audit Format (UAF) 조립을 전담하는 스태틱 유틸리티
 */
class CXAuditFormatter {
public:
    /**
     * @brief 표준화된 로그 메시지 조립
     * @param action 동작 명칭 (Block 1)
     * @param xp 실행 파라미터 (Block 2, 3 추출용)
     * @param specData 클래스별 특화 데이터 (Block 4)
     * @param stable volatile 데이터(현재가 등) 제외 여부 (v16.15)
     */
    static string Build(string action, ICXParam* xp, string specData = "", bool stable = false) {
        if(IS_INVALID(xp)) return StringFormat("[FUNC:%s] INVALID_PARAM", action);
        
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return StringFormat("[FUNC:%s] INVALID_SIGNAL", action);

        // [v14.4 Magic Number Mandate] [FUNC:Name] [SID] [TK:Value, M:Magic] [Sym, Lot, Dir, Status]
        string block1 = StringFormat("[FUNC:%s] [%s] [TK:%I64u, M:%I64d] [%s, %.2f, %s, %s]",
                                       action, 
                                       sig.GetSid(), 
                                       sig.GetTicket(),
                                       sig.GetMagic(),
                                       sig.GetSymbol(), 
                                       sig.GetLot(), 
                                       GetDirName((ENUM_CX_DIRECTION)sig.GetDir()),
                                       GetStatusName((ENUM_XE_STATUS)sig.GetStatus()));

        // [ESTART, ELIMIT]
        string symbol = sig.GetSymbol();
        double mkt = 0;
        if(!stable) mkt = SymbolInfoDouble(symbol, (sig.GetDir() == CX_DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);

        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double dirSign = (sig.GetDir() == CX_DIR_BUY) ? -1.0 : 1.0; 
        
        // TE Estimate (Stable 모드에서는 가격 계산 생략)
        double tesp = (!stable && sig.GetTEStart() >= 1) ? mkt + (sig.GetTEStart() * point * dirSign) : 0.0;
        double telp = (!stable && sig.GetTELimit() >= 1) ? mkt + (sig.GetTELimit() * point * dirSign) : 0.0;

        string block2 = StringFormat("[ESTART:%d, ESTEP:%d, ELIMIT:%d, ESTART_PRICE:%.2f, ELIMIT_PRICE:%.2f SSTART:%d, SSTEP:%d SL:%d TP:%d]",
                                       (int)sig.GetTEStart(),
                                       (int)sig.GetTEStep(),
                                       (int)sig.GetTELimit(),
                                       tesp, telp,
                                       (int)sig.GetTSStart(),
                                       (int)sig.GetTSStep(),
                                       (int)sig.GetSL(), 
                                       (int)sig.GetTP());

        // [P:Open, SL:Price, TP:Price, Mkt:Price] - Stable 모드에서는 생략 또는 고정값
        string block3 = "";
        if(!stable) {
            block3 = StringFormat(" [P:%.2f, SL:%.2f, TP:%.2f, Mkt:%.2f]",
                                     sig.GetPriceOpen(), 
                                     sig.GetPriceSL(), 
                                     sig.GetPriceTP(), 
                                     mkt);
        } else {
            block3 = StringFormat(" [P:%.2f, SL:%.2f, TP:%.2f, Mkt:STABLE]",
                                     sig.GetPriceOpen(), 
                                     sig.GetPriceSL(), 
                                     sig.GetPriceTP());
        }

        // 최종 결합 (SPEC 유무에 따라 처리)
        string finalMsg = block1 + " " + block2 + block3;
        if(specData != "") {
            finalMsg += " {" + specData + "}";
        }
        
        return finalMsg;
    }

private:
    static string GetDirName(ENUM_CX_DIRECTION dir) {
        switch(dir) {
            case CX_DIR_BUY:  return "BUY";
            case CX_DIR_SELL: return "SELL";
            default:          return "N/A";
        }
    }

    static string GetStatusName(ENUM_XE_STATUS status) {
        switch(status) {
            case XE_READY:          return "READY";
            case XE_PENDING_REQ:    return "PEND_REQ";
            case XE_IN_TRANSIT:     return "TRANSIT";
            case XE_PENDING_PLACED: return "PEND_PLACED";
            case XE_EXECUTED:       return "EXEC";
            case XE_CLOSED_SIGNAL:  return "CLSD_SIG";
            case XE_CLOSED_SL:      return "CLSD_SL";
            case XE_CLOSED_TP:      return "CLSD_TP";
            case XE_CLOSED_MANUAL:  return "CLSD_MAN";
            case XE_ERROR:          return "ERROR";
            default:                return "UNKNOWN";
        }
    }
};

#endif
