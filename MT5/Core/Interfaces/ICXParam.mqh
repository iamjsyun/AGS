#ifndef ICXPARAM_MQH
#define ICXPARAM_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"

class ICXSignal;
class ICXContext;

class ICXParam : public CObject {
public:
    virtual ~ICXParam() {}
    virtual ICXSignal* GetSignal() = 0;
    virtual void SetSignal(ICXSignal* sig) = 0;
    
    virtual ENUM_CX_EVENT GetEvent() const = 0;
    virtual void SetEvent(ENUM_CX_EVENT event) = 0;
    virtual string GetString() const = 0;
    virtual void SetString(string val) = 0;
    virtual ICXContext* GetContext() = 0;
    virtual void SetContext(ICXContext* ctx) = 0;
    virtual void Reset() = 0;

    virtual double GetDouble() const = 0;
    virtual void   SetDouble(double val) = 0;

    virtual int    GetInt() const = 0;
    virtual void   SetInt(int val) = 0;
    
    virtual long   GetLong() const = 0;
    virtual void   SetLong(long val) = 0;

    virtual void   SetTransaction(const MqlTradeTransaction& trans) = 0;
    virtual void   GetTransaction(MqlTradeTransaction& trans) const = 0;
    
    //--- Dual-Binding Context (v2.0)
    virtual ICXContext* Global() = 0;
    virtual void        SetGlobal(ICXContext* globalCtx) = 0;
    virtual ICXContext* Local() = 0;
    virtual void        SetLocal(ICXContext* localCtx) = 0;

    //--- Dynamic Property Bag (v2.0)
    virtual ICXParam*   SetDouble(string key, double val) = 0;
    virtual double      GetDouble(string key, double defaultVal=0.0) const = 0;

    virtual ICXParam*   SetInt(string key, int val) = 0;
    virtual int         GetInt(string key, int defaultVal=0) const = 0;
    
    virtual ICXParam*   SetLong(string key, long val) = 0;
    virtual long        GetLong(string key, long defaultVal=0) const = 0;

    virtual ICXParam*   SetString(string key, string val) = 0;
    virtual string      GetString(string key, string defaultVal="") const = 0;

    virtual ICXParam*   SetObject(string key, CObject* val) = 0;
    virtual CObject*    GetObject(string key) const = 0;
    
    //--- Factory (v15.2)
    virtual ICXParam* CreateEmptyParam() = 0;
};#endif
