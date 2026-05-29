#ifndef CXDATABASE_MQH
#define CXDATABASE_MQH

#include "..\Interfaces\IDatabase.mqh"
#include "..\Defines\CXDefine.mqh"
#include "..\Macros\CXMacros.mqh"

/**
 * @class CXDatabase
 * @brief 샌드박스화된 세션 전용 SQLite 핸들러
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
     */
    virtual bool Open(string dbName = "ATS.db", bool isCommon = true) override {
        int flags = DATABASE_OPEN_READWRITE;
        if(isCommon) flags |= DATABASE_OPEN_COMMON;

        m_db = DatabaseOpen(dbName, flags);
        
        string pathType = isCommon ? "Terminal\\Common\\Files" : "MQL5\\Files";

        // 1. 파일 존재 여부 확인
        if(m_db == INVALID_HANDLE) {
            string err = StringFormat("CRITICAL: Database file NOT FOUND!\nFile: %s\nPath: %s\n\nATSA(DataManager) must create the database first.", dbName, pathType);
            Print(err);
            return false;
        }
        
        // 2. 스키마 무결성 검증 (핵심 테이블 존재 확인)
        int hCheck = DatabasePrepare(m_db, "SELECT name FROM sqlite_master WHERE type='table' AND name='signals'");
        if(hCheck == INVALID_HANDLE || !DatabaseRead(hCheck)) {
            if(hCheck != INVALID_HANDLE) DatabaseFinalize(hCheck);
            string err = StringFormat("CRITICAL: Database Schema Mismatch!\nTable 'signals' not found in %s.\n\nPlease check if you are using the correct ATS.db file.", dbName);
            Print(err);
            return false;
        }
        DatabaseFinalize(hCheck);

        DatabaseExecute(m_db, "PRAGMA journal_mode=WAL;");
        DatabaseExecute(m_db, "PRAGMA synchronous=NORMAL;");
        
        // [v1.1] Create atse_log table if not exists
        DatabaseExecute(m_db, "CREATE TABLE IF NOT EXISTS atse_log ("
                              "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                              "sid TEXT NOT NULL, "
                              "created DATETIME DEFAULT (datetime('now', 'localtime')), "
                              "level TEXT NOT NULL, "
                              "msg TEXT NOT NULL"
                              ");");

        PrintFormat("[DB-OK] Connected to %s (%s)", dbName, pathType);
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


