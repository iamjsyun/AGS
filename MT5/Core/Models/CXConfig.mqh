#ifndef CXCONFIG_MQH
#define CXCONFIG_MQH

#include "..\Interfaces\ICXConfig.mqh"
#include <Arrays\ArrayLong.mqh>

class CXConfig : public ICXConfig {
private:
    string         m_targetMagics;
    CArrayLong     m_magics;
    double         m_timerInterval;
    string         m_remoteAddr;
    
    bool           m_log_ui;
    bool           m_log_remote;
    string         m_log_filter_cnos;
    ENUM_LOG_LEVEL m_log_level;

    bool           m_watcher_file;
    bool           m_watcher_remote;
    bool           m_watcher_init;

    bool           m_system_file;
    bool           m_system_remote;
    bool           m_system_init;

    bool           m_session_file;
    bool           m_session_remote;
    bool           m_session_ui;
    bool           m_session_init;

    string         m_dbName;
    bool           m_dbCommon;

public:
    CXConfig(string targetMagics, double timerInterval, string remoteAddr,
             bool logUI, bool logRemote, string logFilterCnos, ENUM_LOG_LEVEL logLevel,
             bool watcherFile, bool watcherRemote, bool watcherInit,
             bool systemFile, bool systemRemote, bool systemInit,
             bool sessionFile, bool sessionRemote, bool sessionUI, bool sessionInit,
             string dbName, bool dbCommon)
        : m_targetMagics(targetMagics), m_timerInterval(timerInterval), m_remoteAddr(remoteAddr),
          m_log_ui(logUI), m_log_remote(logRemote), m_log_filter_cnos(logFilterCnos), m_log_level(logLevel),
          m_watcher_file(watcherFile), m_watcher_remote(watcherRemote), m_watcher_init(watcherInit),
          m_system_file(systemFile), m_system_remote(systemRemote), m_system_init(systemInit),
          m_session_file(sessionFile), m_session_remote(sessionRemote), m_session_ui(sessionUI), m_session_init(sessionInit),
          m_dbName(dbName), m_dbCommon(dbCommon) {
        
        InitializeMagics();
    }

    CXConfig(string targetMagics, double timerInterval, string remoteAddr,
             string dbName, bool dbCommon)
        : m_targetMagics(targetMagics), m_timerInterval(timerInterval), m_remoteAddr(remoteAddr),
          m_log_ui(false), m_log_remote(false), m_log_filter_cnos(""), m_log_level(LOG_LVL_ERROR),
          m_watcher_file(false), m_watcher_remote(false), m_watcher_init(false),
          m_system_file(false), m_system_remote(false), m_system_init(false),
          m_session_file(false), m_session_remote(false), m_session_ui(false), m_session_init(false),
          m_dbName(dbName), m_dbCommon(dbCommon) {
        
        InitializeMagics();
    }

private:
    void InitializeMagics() {
        string parts[];
        int count = StringSplit(m_targetMagics, ',', parts);
        for(int i = 0; i < count; i++) {
            string s = parts[i];
            StringTrimLeft(s); StringTrimRight(s);
            m_magics.Add(StringToInteger(s));
        }
    }

public:

    virtual string GetTargetMagics() const override { return m_targetMagics; }
    virtual bool IsTargetMagic(long magic) const override {
        for(int i = 0; i < m_magics.Total(); i++) {
            if(m_magics.At(i) == magic) return true;
        }
        return false;
    }

    virtual double GetTimerInterval() const override { return m_timerInterval; }
    virtual string GetRemoteLogHost() const override { return m_remoteAddr; }
    virtual int    GetRemoteLogPort() const override { return 878; } // Standard port
    
    virtual bool           IsUILogEnabled() const override { return m_log_ui; }
    virtual bool           IsRemoteLogEnabled() const override { return m_log_remote; }
    virtual bool           IsBootLogEnabled() const override { return true; }
    virtual bool           IsWatcherRemoteLogEnabled() const override { return m_watcher_remote; }
    virtual bool           IsSystemLogEnabled() const override { return m_system_file; }
    virtual bool           IsSequenceLogEnabled(long cno) const override { return true; }
    virtual string         GetLogFilterCnos() const { return m_log_filter_cnos; }
    virtual ENUM_LOG_LEVEL GetLogLevel() const override { return m_log_level; }

    virtual bool IsFileLogEnabled(string category) const override {
        if(category == "Watcher") return m_watcher_file;
        if(category == "System")  return m_system_file;
        if(category == "Session") return m_session_file;
        return true;
    }

    virtual bool IsRemoteLogEnabled(string category) const override {
        if(category == "Watcher") return m_watcher_remote;
        if(category == "System")  return m_system_remote;
        if(category == "Session") return m_session_remote;
        return true;
    }

    virtual bool IsUILogEnabled(string category) const override {
        if(category == "Session") return m_session_ui;
        return m_log_ui;
    }

    virtual bool IsCnoLogEnabled(long cno) const override { return true; }

    virtual bool IsLogInitOnStart(string category) const override {
        if(category == "Watcher") return m_watcher_init;
        if(category == "System")  return m_system_init;
        if(category == "Session") return m_session_init;
        return true;
    }

    // Database Configuration
    virtual string GetDatabaseName() const override { return m_dbName; }
    virtual bool   IsDatabaseCommon() const override { return m_dbCommon; }
};

#endif
