#ifndef CXSIGNAL_MQH
#define CXSIGNAL_MQH

#include "..\Interfaces\ICXSignal.mqh"
#include "..\Defines\CXDefine.mqh"

/**
 * @class CXSignal
 * @brief 시스템 전반에서 사용되는 신호 엔티티 (Schema SSOT 적용)
 */
class CXSignal : public ICXSignal {
public:
    //--- [1] 멤버 변수 자동 생성
    #define X(type, name, dbType, getter) type name;
    SIGNAL_SCHEMA_FIELDS
    #undef X

    //--- 런타임 전용 필드 (비영속)
    int       last_status; 
    int       ts_start;
    int       ts_step;

    CXSignal() {
        Reset();
    }

    /**
     * @brief [SSOT] 모든 필드를 표준 초기값으로 리셋.
     * @details [v18.27 Fix] string 객체에 ZeroMemory 사용 시 내부 포인터 파손으로 인한 크래시 발생 방지를 위해 개별 초기화 수행.
     */
    void Reset() {
        id = 0;
        sid = "";
        cno = 0;
        sno = 0;
        msg_id = 0;
        raw_id = 0;
        xa_entry = 0;
        xa_exit = 0;
        xe_status = 0;
        xe_status_msg = "";
        time = "";
        symbol = "";
        dir = 0;
        type = 0;
        price_signal = 0.0;
        te_start = 0.0;
        te_step = 0.0;
        te_limit = 0.0;
        te_interval = 0;
        ikte_start = 0.0;
        ikte_step = 0.0;
        tp = 0.0;
        sl = 0.0;
        ts_start = 0;
        ts_step = 0;
        close_type = 0;
        price = 0.0;
        price_open = 0.0;
        price_close = 0.0;
        price_tp = 0.0;
        price_sl = 0.0;
        lot = 0.0;
        ticket = 0;
        magic = 0;
        comment = "";
        tag = "";
        created = 0;
        updated = 0;
        
        last_status = -1;
    }

    virtual ~CXSignal() override {}

    //--- [2] 인터페이스 접근자 수동 전개 (SetSid, SetGid 커스터마이징을 위해 매크로 최소화)
    // Getters
    #define X(type, name, dbType, getter) virtual type Get##getter() const override { return name; }
    SIGNAL_SCHEMA_FIELDS
    #undef X

    // Setters (수동 구현)
    virtual void SetId(int v) override { id = v; }
    virtual void SetSid(string v) override { sid = v; StringTrimLeft(sid); StringTrimRight(sid); }
    virtual void SetCno(int v) override { cno = v; }
    virtual void SetSno(int v) override { sno = v; }
    virtual void SetMsgId(int v) override { msg_id = v; }
    virtual void SetRawId(int v) override { raw_id = v; }
    virtual void SetXAEntry(int v) override { xa_entry = v; }
    virtual void SetXAExit(int v) override { xa_exit = v; }
    virtual void SetStatus(int v) override { xe_status = v; }
    virtual void SetStatusMsg(string v) override { xe_status_msg = v; }
    virtual void SetTime(string v) override { time = v; }
    virtual void SetSymbol(string v) override { symbol = v; }
    virtual void SetDir(int v) override { dir = v; }
    virtual void SetType(int v) override { type = v; }
    virtual void SetPriceSignal(double v) override { price_signal = v; }
    virtual void SetTEStart(double v) override { te_start = v; }
    virtual void SetTEStep(double v) override { te_step = v; }
    virtual void SetTELimit(double v) override { te_limit = v; }
    virtual void SetTEInterval(int v) override { te_interval = v; }
    virtual void SetIkTeStart(double v) override { ikte_start = v; }
    virtual void SetIkTeStep(double v) override { ikte_step = v; }
    virtual void SetTP(double v) override { tp = v; }
    virtual void SetSL(double v) override { sl = v; }
    virtual void SetTSStart(int v) override { ts_start = v; }
    virtual void SetTSStep(int v) override { ts_step = v; }
    virtual int  GetTSStart() const override { return ts_start; }
    virtual int  GetTSStep() const override { return ts_step; }
    virtual void SetCloseType(int v) override { close_type = v; }
    virtual void SetPrice(double v) override { price = v; }
    virtual void SetPriceOpen(double v) override { price_open = v; }
    virtual void SetPriceClose(double v) override { price_close = v; }
    virtual void SetPriceTP(double v) override { price_tp = v; }
    virtual void SetPriceSL(double v) override { price_sl = v; }
    virtual void SetLot(double v) override { lot = v; }
    virtual void SetTicket(ulong v) override { ticket = v; }
    virtual void SetMagic(long v) override { magic = v; }
    virtual void SetComment(string v) override { comment = v; }
    virtual void SetTag(string v) override { tag = v; }
    virtual void SetCreated(datetime v) override { created = v; }
    virtual void SetUpdated(datetime v) override { updated = v; }

    //--- [3] 수동 구현이 필요한 특수 로직
    virtual int GetGno() const override {
        string parts[];
        if (StringSplit(sid, '-', parts) >= 4) return (int)StringToInteger(parts[3]);
        return 0;
    }
    
    virtual void   UpdatePriceSignal(double p) override { price_signal = p; }
    virtual double GetOffset() const override { return 0; } 
    
    //--- [v11.0] Log Spam Prevention
    virtual int    GetLastStatus() const override { return last_status; }
    virtual void   SetLastStatus(int status) override { last_status = status; }
};

#endif
