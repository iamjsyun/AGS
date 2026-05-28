#ifndef ICXCONTEXT_MQH
#define ICXCONTEXT_MQH

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>

class ICXParam;
class ICXConfig;
class ICXLogger;
class ICXSignal;

/**
 * @class ICXContext
 * @brief 서비스 간 의존성 및 공유 파라미터 관리를 위한 컨텍스트 인터페이스
 */
class ICXContext : public CObject {
public:
    virtual ~ICXContext() {}
    
    virtual string      GetName() const = 0;
    virtual void        Register(string key, CObject* obj) = 0;
    virtual CObject*    Get(string key) = 0;
    virtual void        Remove(string key) = 0;

    //--- Typed Accessors
    virtual ICXParam*   GetParam(string key) = 0;
    virtual ICXConfig*  GetConfig() = 0;
    virtual ICXLogger*  GetLogger() const = 0;

    //--- Hierarchy Support
    virtual ICXContext* CreateChildContext() = 0;
    virtual void        AddChild(string name, ICXContext* child) = 0;
    virtual void        RemoveChild(string name) = 0;
    virtual ICXContext* GetChild(string name) = 0;

    //--- SSOC & Lifecycle (v15.2)
    virtual void        SetParam(ICXParam* p) = 0;
    virtual ICXParam*   GetParam() = 0;
    virtual void        Set(string key, CObject* obj) = 0;
    virtual string      Snapshot(int indent = 0) = 0;
};

#endif
