#ifndef CXDBLOGGER_MQH
#define CXDBLOGGER_MQH

#include "..\..\Core\Interfaces\ICXLogger.mqh"
#include "..\..\Core\Interfaces\IDatabase.mqh"
#include "..\..\Core\Interfaces\ICXSignal.mqh"
#include "..\..\Core\Interfaces\ICXParam.mqh"
#include "..\..\Core\Interfaces\ICXContext.mqh"
#include "..\..\Core\Defines\CXDefine.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"

/**
 * @class CXDbLogger
 * @brief [v1.1] SQLite 데이터베이스(atse_log 테이블)에 로그를 구조화하여 기록하는 채널 클래스
 */
class CXDbLogger : public ICXLogger {
private:
    IDatabase* m_db;
    bool       m_enabled;

    //--- Helper to parse Task Name from CXAuditFormatter output
    string ParseTask(string msg) {
        int pos = StringFind(msg, "[FUNC:");
        if(pos >= 0) {
            int endPos = StringFind(msg, "]", pos);
            if(endPos > pos + 6) {
                return StringSubstr(msg, pos + 6, endPos - pos - 6);
            }
        }
        return "System";
    }

    //--- Helper to map Task to Stage Name
    string GetStageFromTask(string task) {
        string t = task;
        StringToUpper(t);
        if(StringFind(t, "DISCOVERY") >= 0 || StringFind(t, "WATCHER") >= 0) return "StageDiscovery";
        if(StringFind(t, "PEND") >= 0 || StringFind(t, "ENTRY") >= 0 || StringFind(t, "GUARD") >= 0) return "StageEntryExecute";
        if(StringFind(t, "TS-WATCH") >= 0 || StringFind(t, "ALPHA") >= 0 || StringFind(t, "CLOSED") >= 0) return "StageActiveExecute";
        if(StringFind(t, "EXIT") >= 0 || StringFind(t, "LIQ") >= 0) return "StageExitExecute";
        return "StageActiveExecute"; // Default
    }

public:
    CXDbLogger(IDatabase* db) : m_db(db), m_enabled(true) {}
    virtual ~CXDbLogger() override {}

    virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
    virtual bool IsEnabled() const override { return m_enabled; }

    virtual void Log(ENUM_LOG_LEVEL level, string msg) override {
        // Fallback: direct string log when no parameter context is provided
        if(!m_enabled || IS_INVALID(m_db)) return;
        if(level == LOG_LVL_TRACE || level == LOG_LVL_DEBUG) return;

        string lvlStr = EnumToString(level);
        string cleanMsg = msg;
        StringReplace(cleanMsg, "'", "''");

        string sql = StringFormat(
            "INSERT INTO atse_log (sid, level, msg) VALUES ('System', '%s', '%s')",
            lvlStr, cleanMsg
        );
        m_db.Execute(sql);
    }

    virtual void Dispatch(ENUM_LOG_LEVEL level, ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE) override {
        if(!m_enabled || IS_INVALID(m_db)) return;
        if(level == LOG_LVL_TRACE || level == LOG_LVL_DEBUG) return;

        ICXSignal* sig = (IS_VALID(xp)) ? xp.GetSignal() : NULL;
        if(IS_INVALID(sig)) {
            // Context가 없으면 Fallback 일반 로그로 기록
            Log(level, msg);
            return;
        }

        // 중복 방지 필터 적용
        string sid = sig.GetSid();
        string task = ParseTask(msg);
        string uniqueKey = StringFormat("[%s:%s] %s", sid, task, msg);
        if(!ShouldLog(uniqueKey, policy)) return;

        // Context 변수 정보 추출 및 매핑
        string stage = GetStageFromTask(task);
        int seqState = sig.GetStatus(); // xe_status를 Sequence State ID로 사용
        int xa_entry = sig.GetXAEntry();
        int xa_exit = sig.GetXAExit();
        int xe_status = sig.GetStatus();
        string statusMsg = sig.GetStatusMsg();
        
        double lot = sig.GetLot();
        double sl = sig.GetSL();
        double tp = sig.GetTP();
        
        double te_start = sig.GetTEStart();
        double te_step = sig.GetTEStep();
        double te_limit = sig.GetTELimit();
        double ikte_start = sig.GetIkTeStart();
        double ikte_step = sig.GetIkTeStep();
        
        string symbol = sig.GetSymbol();
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(point <= 0.0) point = 0.00001; // Safe Guard

        // 기준 가격(entry_price) 산출
        double entry_price = (sig.GetTicket() > 0 || sig.GetPriceOpen() > 0) ? sig.GetPriceOpen() : sig.GetPriceSignal();
        double price_signal = sig.GetPriceSignal();
        double price_open = sig.GetPriceOpen();
        if(price_open <= 0) price_open = entry_price; // fallback if price_open is not populated yet
        
        // 트레일링 가격 정보 계산 (포인트 -> 가격 환산)
        double te_start_price = 0.0;
        double te_limit_price = 0.0;
        double ikte_start_price = 0.0;

        if(sig.GetDir() == CX_DIR_BUY) {
            te_start_price = entry_price - (te_start * point);
            te_limit_price = price_signal - (te_limit * point);
            ikte_start_price = price_open + (ikte_start * point);
        } else {
            te_start_price = entry_price + (te_start * point);
            te_limit_price = price_signal + (te_limit * point);
            ikte_start_price = price_open - (ikte_start * point);
        }

        // 표준 포맷 메시지 조립
        string payload = StringFormat(
            "%s | SID:%s, Stage:%s, Task:%s, SeqState:%d, XA:(%d,%d), XE:%d, Lot:%.2f, SL:%.2f, TP:%.2f, Parameters:[TE_Start:%.0f(P:%.2f), TE_Step:%.0f, TE_Limit:%.0f(P:%.2f), IK_Start:%.0f(P:%.2f), IK_Step:%.0f], Msg:\"%s\"",
            msg, sid, stage, task, seqState, xa_entry, xa_exit, xe_status, lot, sl, tp, 
            te_start, te_start_price, te_step, te_limit, te_limit_price, 
            ikte_start, ikte_start_price, ikte_step, statusMsg
        );

        // SQL Injection 방지를 위한 작은 따옴표 이스케이프
        StringReplace(payload, "'", "''");
        string lvlStr = EnumToString(level);

        string sql = StringFormat(
            "INSERT INTO atse_log (sid, level, msg) VALUES ('%s', '%s', '%s')",
            sid, lvlStr, payload
        );
        m_db.Execute(sql);
    }
};

#endif
