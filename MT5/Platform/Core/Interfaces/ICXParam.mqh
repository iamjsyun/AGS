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
    
    //--- Factory (v15.2)
    virtual ICXParam* CreateEmptyParam() = 0;
};#endif
