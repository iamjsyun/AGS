#ifndef CXDATABASE_MQH
#define CXDATABASE_MQH

#include "..\Interfaces\IDatabase.mqh"
#include "..\Defines\CXDefine.mqh"
#include "..\Macros\CXMacros.mqh"

/**
 * @class CXDatabase
 * @brief Sandbox-enabled session-exclusive SQLite handler
 */
class CXDatabase : public IDatabase {
private:
    int     m_db;
    string  m_db_path;

public:
    CXDatabase() : m_db(INVALID_HANDLE), m_db_path("ATS.db") {}
    virtual ~CXDatabase() { Close(); }

    /**
     * @brief [v14.47 Sync] Unified Open logic matching interface
     * [v2.1 Update] Added DATABASE_OPEN_CREATE and auto-schema initialization
     */
    virtual bool Open(string dbName = "AGS.db", bool isCommon = true) override {
        int flags = DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE;
        if(isCommon) flags |= DATABASE_OPEN_COMMON;

        bool isNew = !FileIsExist(dbName, isCommon ? FILE_COMMON : 0);
        m_db = DatabaseOpen(dbName, flags);
        
        if(m_db == INVALID_HANDLE) {
            PrintFormat("[DB-ERR] Failed to open/create database %s. Error: %d", dbName, GetLastError());
            return false;
        }

        if(isNew) {
            PrintFormat("[DB-CREATE-OK] New database created and initialized: %s", dbName);
        } else {
            PrintFormat("[DB-OPEN-OK] Existing database opened successfully: %s", dbName);
        }

        // Initialize schema if not exists
        DatabaseExecute(m_db, "CREATE TABLE IF NOT EXISTS signals ("
                              "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                              "sid TEXT UNIQUE NOT NULL, "
                              "cno INTEGER, sno INTEGER, msg_id INTEGER, raw_id INTEGER, "
                              "xa_entry INTEGER DEFAULT 0, xa_exit INTEGER DEFAULT 0, "
                              "xe_status INTEGER DEFAULT 0, xe_status_msg TEXT, "
                              "time TEXT, symbol TEXT, dir INTEGER, type INTEGER, "
                              "price_signal REAL, te_start REAL, te_step REAL, te_limit REAL, te_interval INTEGER, "
                              "ikte_start REAL, ikte_step REAL, tp REAL, sl REAL, "
                              "close_type INTEGER, price REAL, price_open REAL, price_close REAL, price_tp REAL, price_sl REAL, "
                              "lot REAL, ticket INTEGER, magic INTEGER, comment TEXT, tag TEXT, "
                              "created TEXT DEFAULT (datetime('now', 'localtime')), "
                              "updated TEXT DEFAULT (datetime('now', 'localtime'))"
                              ");");
        
        DatabaseExecute(m_db, "CREATE TABLE IF NOT EXISTS ags_log ("
                              "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                              "sid TEXT NOT NULL, "
                              "created DATETIME DEFAULT (datetime('now', 'localtime')), "
                              "level TEXT NOT NULL, "
                              "msg TEXT NOT NULL"
                              ");");

        DatabaseExecute(m_db, "PRAGMA journal_mode=WAL;");
        DatabaseExecute(m_db, "PRAGMA synchronous=NORMAL;");

        PrintFormat("[DB-OK] Connected to %s", dbName);
        return true;
    }

    virtual void Close() override {
        if(m_db != INVALID_HANDLE) {
            DatabaseClose(m_db);
            m_db = INVALID_HANDLE;
        }
    }

    virtual bool Execute(string sql) override {
        if(m_db == INVALID_HANDLE) return false;
        return DatabaseExecute(m_db, sql);
    }

    virtual int GetHandle() override { return m_db; }
};

#endif
