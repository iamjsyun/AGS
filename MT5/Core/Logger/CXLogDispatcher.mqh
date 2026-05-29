#ifndef CXLOGDISPATCHER_MQH
#define CXLOGDISPATCHER_MQH

#include "..\Interfaces\ICXLogger.mqh"
#include "..\Interfaces\ICXConfig.mqh"
#include "..\Interfaces\IDatabase.mqh"
#include "..\Macros\CXMacros.mqh"
#include "CXDbLogger.mqh"
#include <Arrays\ArrayObj.mqh>

/**
 * @class CXLogDispatcher
 * @brief 세션별 4대 채널(File, Tab, UI, Remote) 로그 통합 관리 및 배분
 */
class CXLogDispatcher : public ICXLogger {
private:
    ICXLogger* m_file;
    ICXLogger* m_tab;
    ICXLogger* m_ui;
    ICXLogger* m_remote;
    ICXLogger* m_db; // [v1.1] SQLite DB logger
    ICXConfig* m_config;
    bool       m_enabled;

public:
    CXLogDispatcher() : m_file(NULL), m_tab(NULL), m_ui(NULL), m_remote(NULL), m_db(NULL), m_config(NULL), m_enabled(true) {
    }
    
    virtual ~CXLogDispatcher() override {
        SAFE_DELETE(m_file);
        SAFE_DELETE(m_tab);
        SAFE_DELETE(m_ui);
        SAFE_DELETE(m_remote);
        SAFE_DELETE(m_db);
    }

    void SetConfig(ICXConfig* config) { m_config = config; }

    virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
    virtual bool IsEnabled() const override { return m_enabled; }
    
    // Helper to replace repetitive IS_VALID checks
    static bool IsOk(const void* ptr) { return CheckPointer(ptr) != POINTER_INVALID; }

    virtual void Log(ENUM_LOG_LEVEL level, string msg) override {
        if(!m_enabled) return;

        // 1. File Logger
        if(IsOk(m_file) && m_file.IsEnabled()) m_file.Log(level, msg);
        
        // 2. MT5 Tab (Journal) - Mirroring Mandate (v11.5)
        if(IsOk(m_tab) && m_tab.IsEnabled()) {
            m_tab.Log(level, msg);
        } else {
            PrintFormat("[%s] %s", EnumToString(level), msg);
        }

        // 3. UI & Remote (Check global config)
        if(IsOk(m_config)) {
            if(IsOk(m_ui) && m_ui.IsEnabled() && m_config.IsUILogEnabled()) 
                m_ui.Log(level, msg);
            
            if(IsOk(m_remote) && m_remote.IsEnabled() && m_config.IsRemoteLogEnabled()) 
                m_remote.Log(level, msg);
        }
    }

    virtual void Dispatch(ENUM_LOG_LEVEL level, ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE) override {
        if(!m_enabled) return;
        if(IsOk(m_db) && m_db.IsEnabled()) {
            m_db.Dispatch(level, xp, msg, policy);
        }
        ICXLogger::Dispatch(level, xp, msg, policy);
    }


    void SetDatabase(IDatabase* db) {
        SAFE_DELETE(m_db);
        if(IS_VALID(db)) {
            m_db = new CXDbLogger(db);
        }
    }

    void SetFileLogger(ICXLogger* logger)   { SAFE_DELETE(m_file);   m_file = logger; }
    void SetTabLogger(ICXLogger* logger)    { SAFE_DELETE(m_tab);    m_tab = logger; }
    void SetUILogger(ICXLogger* logger)     { SAFE_DELETE(m_ui);     m_ui = logger; }
    void SetRemoteLogger(ICXLogger* logger) { SAFE_DELETE(m_remote); m_remote = logger; }

    ICXLogger* GetFileLogger() const { return m_file; }

    /**
     * @brief 로그 채널 옵션 변경
     */
    void Configure(bool useFile, bool useTab, bool useUI, bool useRemote) {
        if(IsOk(m_file))   m_file.SetEnabled(useFile);
        if(IsOk(m_tab))    m_tab.SetEnabled(useTab);
        if(IsOk(m_ui))     m_ui.SetEnabled(useUI);
        if(IsOk(m_remote)) m_remote.SetEnabled(useRemote);
    }
};

#endif
