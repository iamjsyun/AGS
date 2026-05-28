#ifndef CXPARAM_MQH
#define CXPARAM_MQH

#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXContext.mqh"

/**
 * @class CXParam
 * @brief 트레이딩 이벤트 및 데이터를 전달하는 기본 DTO 클래스
 */
class CXParam : public ICXParam {
protected:
    ICXSignal*           m_sig;
    int                  m_val;
    long                 m_long;
    double               m_double;
    string               m_str;
    ICXContext*          m_ctx;
    ENUM_CX_EVENT        m_event;
    MqlTradeTransaction  m_trans;

public:
    CXParam() : m_sig(NULL), m_val(0), m_long(0), m_double(0.0), m_str(""), m_ctx(NULL), m_event(EVENT_TICK) {
        ZeroMemory(m_trans);
    }
    virtual ~CXParam() {
    }

    //-- Interface Implementation
    virtual ICXSignal* GetSignal() override { return m_sig; }
    virtual ICXContext* GetContext() override { return m_ctx; }
    
    virtual ENUM_CX_EVENT GetEvent() const override { return m_event; }
    virtual void SetEvent(ENUM_CX_EVENT event) override { m_event = event; }

    virtual string GetString() const override { return m_str; }
    virtual void   SetString(string val) override { m_str = val; }

    virtual double GetDouble() const override { return m_double; }
    virtual void   SetDouble(double val) override { m_double = val; }

    virtual int    GetInt() const override { return m_val; }
    virtual void   SetInt(int val) override { m_val = val; }

    virtual void   Reset() override {
        m_sig = NULL;
        m_val = 0;
        m_long = 0;
        m_double = 0.0;
        m_str = "";
        ZeroMemory(m_trans);
    }
    
    virtual long   GetLong() const override { return m_long; }
    virtual void   SetLong(long val) override { m_long = val; }
    
    //-- Getters & Setters
    virtual void SetSignal(ICXSignal* sig) override { m_sig = sig; }
    virtual void SetContext(ICXContext* ctx) override { m_ctx = ctx; }

    virtual void SetTransaction(const MqlTradeTransaction& trans) override { m_trans = trans; }
    virtual void GetTransaction(MqlTradeTransaction& trans) const override { trans = m_trans; }

    virtual ICXParam* CreateEmptyParam() override { return new CXParam(); }
};

#endif
