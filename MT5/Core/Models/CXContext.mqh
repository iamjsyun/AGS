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
    CHashMap<string, bool>      m_managedFlags;
    CHashMap<string, ICXContext*> m_children;

public:
    CXContext(string name = "Global") : m_name(name), m_param(NULL) {}
    
    ~CXContext() { 
        string keys[]; CObject* vals[];
        m_resources.CopyTo(keys, vals);
        for(int i = 0; i < ArraySize(keys); i++) {
            bool managed = false;
            if(m_managedFlags.TryGetValue(keys[i], managed) && managed) {
                CObject* obj = vals[i];
                if(CheckPointer(obj) == POINTER_DYNAMIC) {
                    delete obj;
                }
            }
        }
        m_resources.Clear(); 
        m_managedFlags.Clear();
        m_children.Clear(); 
        m_param = NULL;
    }

    virtual string GetName() const override { return m_name; }

    virtual ICXParam* GetParam() override { return m_param; }
    virtual void SetParam(ICXParam* p) override { m_param = p; }

    virtual void Set(string key, CObject* obj, bool managed = false) override {
        if(m_resources.ContainsKey(key)) m_resources.Remove(key);
        m_resources.Add(key, obj);
        
        if(m_managedFlags.ContainsKey(key)) m_managedFlags.Remove(key);
        m_managedFlags.Add(key, managed);
    }

    virtual void Register(string key, CObject* obj, bool managed = false) override {
        Set(key, obj, managed);
    }

    virtual CObject* Get(string key) override {
        CObject* obj = NULL;
        if(m_resources.TryGetValue(key, obj)) return obj;
        return NULL;
    }

    virtual void Remove(string key) override {
        if(m_resources.ContainsKey(key)) m_resources.Remove(key);
        if(m_managedFlags.ContainsKey(key)) m_managedFlags.Remove(key);
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
        for(int i = 0; i < ArraySize(keys); i++) {
            child.Register(keys[i], vals[i], false); // Child context must not manage/delete parent resources
        }
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

    virtual bool IsManaged(string key) override {
        bool managed = false;
        if(m_managedFlags.TryGetValue(key, managed)) return managed;
        return false;
    }

    virtual int GetKeys(string &keys[]) override {
        CObject* vals[];
        return m_resources.CopyTo(keys, vals);
    }
};

#endif
