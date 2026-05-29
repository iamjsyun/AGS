#ifndef CXCONTEXT_MQH
#define CXCONTEXT_MQH

#include "..\Interfaces\ICXContext.mqh"
#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXConfig.mqh"
#include "..\Interfaces\ICXLogger.mqh"
#include <Generic\HashMap.mqh>

/**
 * @class CXContext
 * @brief 계층 구조(Tree) 및 스냅샷(Snapshot)을 지원하는 시스템 컨텍스트
 */
class CXContext : public ICXContext {
private:
    string                      m_name;
    ICXParam*                   m_param;
    CHashMap<string, CObject*>  m_resources;
    CHashMap<string, ICXContext*> m_children;

public:
    CXContext(string name = "Global") : m_name(name), m_param(NULL) {}
    
    ~CXContext() { 
        m_resources.Clear(); 
        m_children.Clear(); 
        m_param = NULL;
    }

    virtual string GetName() const override { return m_name; }

    virtual ICXParam* GetParam() override { return m_param; }
    virtual void SetParam(ICXParam* p) override { m_param = p; }

    virtual void Set(string key, CObject* obj) override {
        if(m_resources.ContainsKey(key)) m_resources.Remove(key);
        m_resources.Add(key, obj);
    }

    virtual void Register(string key, CObject* obj) override {
        Set(key, obj);
    }

    virtual CObject* Get(string key) override {
        CObject* obj = NULL;
        if(m_resources.TryGetValue(key, obj)) return obj;
        return NULL;
    }

    virtual void Remove(string key) override {
        if(m_resources.ContainsKey(key)) m_resources.Remove(key);
    }

    virtual ICXParam* GetParam(string key) override {
        CObject* obj = Get(key);
        return (obj != NULL) ? (ICXParam*)obj : NULL;
    }

    virtual ICXConfig* GetConfig() override {
        CObject* obj = Get("config");
        return (obj != NULL) ? (ICXConfig*)obj : NULL;
    }

    virtual ICXLogger* GetLogger() const override {
        // [v18.30 Fix] Bypass const-correctness for non-const Get()
        CXContext* nonConst = (CXContext*)GetPointer(this);
        CObject* obj = nonConst.Get("logger");
        return (obj != NULL) ? (ICXLogger*)obj : NULL;
    }

    virtual ICXContext* CreateChildContext() override {
        CXContext* child = new CXContext(m_name + "_Child");
        string keys[]; CObject* vals[];
        m_resources.CopyTo(keys, vals);
        for(int i = 0; i < ArraySize(keys); i++) child.Register(keys[i], vals[i]);
        return child;
    }

    virtual void AddChild(string name, ICXContext* child) override {
        if(m_children.ContainsKey(name)) m_children.Remove(name);
        if(IS_VALID(child)) m_children.Add(name, child);
    }

    virtual void RemoveChild(string name) override {
        if(m_children.ContainsKey(name)) m_children.Remove(name);
    }

    virtual ICXContext* GetChild(string name) override {
        ICXContext* child = NULL;
        m_children.TryGetValue(name, child);
        return child;
    }

    virtual string Snapshot(int indent = 0) override {
        return "{ Snapshot not implemented }";
    }
};

#endif
