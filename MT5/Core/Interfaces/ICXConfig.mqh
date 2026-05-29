#ifndef ICXCONFIG_MQH
#define ICXCONFIG_MQH

#include <Object.mqh>

class ICXConfig : public CObject {
public:
    virtual ~ICXConfig() {}

    // Magic Number Management
    virtual string GetTargetMagics() const = 0;
    virtual bool   IsTargetMagic(long magic) const = 0;

    // Timer & Performance
    virtual double GetTimerInterval() const = 0;

    // Remote Logging
    virtual string GetRemoteLogHost() const = 0;
    virtual int    GetRemoteLogPort() const = 0;

    // Logging Options
    virtual bool   IsUILogEnabled() const = 0;
    virtual bool   IsRemoteLogEnabled() const = 0;
    virtual bool   IsBootLogEnabled() const = 0;
    virtual bool   IsWatcherRemoteLogEnabled() const = 0;
    virtual bool   IsSystemLogEnabled() const = 0;
    virtual bool   IsSequenceLogEnabled(long cno) const = 0;
    virtual ENUM_LOG_LEVEL GetLogLevel() const = 0;

    // Granular Log Control (v10.0)
    virtual bool   IsFileLogEnabled(string category) const = 0;   // "Watcher", "System", "Session"
    virtual bool   IsRemoteLogEnabled(string category) const = 0; // "Watcher", "System", "Session"
    virtual bool   IsUILogEnabled(string category) const = 0;     // "Watcher", "System", "Session"
    virtual bool   IsCnoLogEnabled(long cno) const = 0;           // Filtering by CNO
    virtual bool   IsLogInitOnStart(string category) const = 0;   // Overwrite log files per category

    // Database Configuration (v10.11)
    virtual string GetDatabaseName() const = 0;
    virtual bool   IsDatabaseCommon() const = 0;
};

#endif
