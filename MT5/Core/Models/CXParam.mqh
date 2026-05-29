#ifndef CXPARAM_MQH
#define CXPARAM_MQH

#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXContext.mqh"
#include <Generic\HashMap.mqh>

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

    // v2.0 UDP Context Binding & Dynamic Properties
    ICXContext*          m_globalCtx;
    ICXContext*          m_localCtx;
    CHashMap<string, double>*   m_doubles;
    CHashMap<string, int>*      m_ints;
    CHashMap<string, long>*     m_longs;
    CHashMap<string, string>*   m_strings;
    CHashMap<string, CObject*>* m_objects;

public:
    CXParam() : m_sig(NULL), m_val(0), m_long(0), m_double(0.0), m_str(""), m_ctx(NULL), m_event(EVENT_TICK),
                m_globalCtx(NULL), m_localCtx(NULL), m_doubles(NULL), m_ints(NULL), m_longs(NULL), m_strings(NULL), m_objects(NULL) {
        ZeroMemory(m_trans);
    }
    virtual ~CXParam() {
        SAFE_DELETE(m_doubles);
        SAFE_DELETE(m_ints);
        SAFE_DELETE(m_longs);
        SAFE_DELETE(m_strings);
        SAFE_DELETE(m_objects);
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
        m_globalCtx = NULL;
        m_localCtx = NULL;
        if(IS_VALID(m_doubles)) m_doubles.Clear();
        if(IS_VALID(m_ints))    m_ints.Clear();
        if(IS_VALID(m_longs))   m_longs.Clear();
        if(IS_VALID(m_strings)) m_strings.Clear();
        if(IS_VALID(m_objects)) m_objects.Clear();
    }
    
    virtual long   GetLong() const override { return m_long; }
    virtual void   SetLong(long val) override { m_long = val; }
    
    //-- Getters & Setters
    virtual void SetSignal(ICXSignal* sig) override { m_sig = sig; }
    virtual void SetContext(ICXContext* ctx) override { m_ctx = ctx; }

    virtual void SetTransaction(const MqlTradeTransaction& trans) override { m_trans = trans; }
    virtual void GetTransaction(MqlTradeTransaction& trans) const override { trans = m_trans; }

    //--- Dual-Binding Context (v2.0)
    virtual ICXContext* Global() override { return m_globalCtx; }
    virtual void        SetGlobal(ICXContext* globalCtx) override { m_globalCtx = globalCtx; }
    virtual ICXContext* Local() override { return m_localCtx; }
    virtual void        SetLocal(ICXContext* localCtx) override { m_localCtx = localCtx; }

    //--- Dynamic Property Bag (v2.0)
    virtual ICXParam* SetDouble(string key, double val) override {
        if(IS_INVALID(m_doubles)) m_doubles = new CHashMap<string, double>();
        if(IS_VALID(m_doubles)) {
            if(m_doubles.ContainsKey(key)) m_doubles.Remove(key);
            m_doubles.Add(key, val);
        }
        return GetPointer(this);
    }
    virtual double GetDouble(string key, double defaultVal=0.0) const override {
        if(IS_INVALID(m_doubles)) return defaultVal;
        double val;
        if(m_doubles.TryGetValue(key, val)) return val;
        return defaultVal;
    }

    virtual ICXParam* SetInt(string key, int val) override {
        if(IS_INVALID(m_ints)) m_ints = new CHashMap<string, int>();
        if(IS_VALID(m_ints)) {
            if(m_ints.ContainsKey(key)) m_ints.Remove(key);
            m_ints.Add(key, val);
        }
        return GetPointer(this);
    }
    virtual int GetInt(string key, int defaultVal=0) const override {
        if(IS_INVALID(m_ints)) return defaultVal;
        int val;
        if(m_ints.TryGetValue(key, val)) return val;
        return defaultVal;
    }

    virtual ICXParam* SetLong(string key, long val) override {
        if(IS_INVALID(m_longs)) m_longs = new CHashMap<string, long>();
        if(IS_VALID(m_longs)) {
            if(m_longs.ContainsKey(key)) m_longs.Remove(key);
            m_longs.Add(key, val);
        }
        return GetPointer(this);
    }
    virtual long GetLong(string key, long defaultVal=0) const override {
        if(IS_INVALID(m_longs)) return defaultVal;
        long val;
        if(m_longs.TryGetValue(key, val)) return val;
        return defaultVal;
    }

    virtual ICXParam* SetString(string key, string val) override {
        if(IS_INVALID(m_strings)) m_strings = new CHashMap<string, string>();
        if(IS_VALID(m_strings)) {
            if(m_strings.ContainsKey(key)) m_strings.Remove(key);
            m_strings.Add(key, val);
        }
        return GetPointer(this);
    }
    virtual string GetString(string key, string defaultVal="") const override {
        if(IS_INVALID(m_strings)) return defaultVal;
        string val;
        if(m_strings.TryGetValue(key, val)) return val;
        return defaultVal;
    }

    virtual ICXParam* SetObject(string key, CObject* val) override {
        if(IS_INVALID(m_objects)) m_objects = new CHashMap<string, CObject*>();
        if(IS_VALID(m_objects)) {
            if(m_objects.ContainsKey(key)) m_objects.Remove(key);
            m_objects.Add(key, val);
        }
        return GetPointer(this);
    }
    virtual CObject* GetObject(string key) const override {
        if(IS_INVALID(m_objects)) return NULL;
        CObject* val = NULL;
        if(m_objects.TryGetValue(key, val)) return val;
        return NULL;
    }

    virtual ICXParam* CreateEmptyParam() override { return new CXParam(); }
};

#endif
