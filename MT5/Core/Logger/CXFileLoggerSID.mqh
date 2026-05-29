#ifndef CXFILELOGGERSID_MQH
#define CXFILELOGGERSID_MQH

#include "..\Interfaces\ICXLogger.mqh"

/**
 * @class CXFileLoggerSID
 * @brief SID(Signal ID)별 독립 로그 파일 생성 및 정밀 기록 담당 (v14.45)
 */
class CXFileLoggerSID : public ICXLogger {
private:
    int    m_handle;
    string m_filename;
    string m_sid;
    int    m_lastHour;
    bool   m_enabled;

public:
    CXFileLoggerSID() : m_handle(INVALID_HANDLE), m_lastHour(-1), m_enabled(true) {}
    ~CXFileLoggerSID() { Close(); }

    /**
     * @brief SID를 기반으로 파일 핸들 초기화
     */
    bool Init(string sid, bool initOnStart = false) {
        m_sid = sid;
        MqlDateTime dt;
        TimeCurrent(dt);
        m_lastHour = dt.hour;

        return OpenByTime(dt, initOnStart);
    }

    virtual void Log(ENUM_LOG_LEVEL level, string msg) override {
        if(!m_enabled) return;

        //-- 시간 변경 감지 시 파일 재연결 (Hourly Rotation)
        MqlDateTime dt;
        TimeCurrent(dt);
        if(dt.hour != m_lastHour) {
            m_lastHour = dt.hour;
            OpenByTime(dt, false); // Rotation is always append
        }

        if(m_handle == INVALID_HANDLE) return;

        // [v14.44 Sync] Unicode 기반 정밀 기록
        string line = StringFormat("[%s] [%s] %s\r\n", EnumToString(level), TimeToString(TimeCurrent(), TIME_SECONDS), msg);
        FileWriteString(m_handle, line);
        FileFlush(m_handle);
    }

private:
    /**
     * @brief {sid}-{yymmdd-HH}0000.log 형식으로 물리적 파일 오픈
     */
    bool OpenByTime(MqlDateTime &dt, bool truncate) {
        Close();

        if(!FolderCreate("ATSE", FILE_COMMON)) {
            int err = GetLastError();
            if(err != 0 && err != 5019) PrintFormat("[LOG-ERR] FolderCreate ATSE failed. Code:%d", err);
        }

        string timestamp = StringFormat("%02d%02d%02d-%02d0000", dt.year % 100, dt.mon, dt.day, dt.hour);
        m_filename = StringFormat("ATSE\\%s-%s.log", m_sid, timestamp);
        
        int sharedFlags = FILE_SHARE_READ|FILE_SHARE_WRITE;
        int flags = FILE_TXT|sharedFlags|FILE_UNICODE|FILE_COMMON;

        if(truncate) {
            FileDelete(m_filename, FILE_COMMON);
        }

        // 1. Try to open for Append (File must exist)
        m_handle = FileOpen(m_filename, flags|FILE_READ|FILE_WRITE);
        
        // 2. If it doesn't exist, create it, close it, and reopen for Append
        if(m_handle == INVALID_HANDLE) {
            int tempHandle = FileOpen(m_filename, flags|FILE_WRITE);
            if(tempHandle != INVALID_HANDLE) FileClose(tempHandle);
            
            // Reopen in Append mode
            m_handle = FileOpen(m_filename, flags|FILE_READ|FILE_WRITE);
        }
        
        if(m_handle != INVALID_HANDLE) FileSeek(m_handle, 0, SEEK_END);

        if(m_handle != INVALID_HANDLE) return true;
        
        PrintFormat("[LOG-CRITICAL] SID File Creation Failed! Path: ATSE\\%s, SID: %s, Error: %d", m_filename, m_sid, GetLastError());
        return false;
    }

public:
    virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
    virtual bool IsEnabled() const override { return m_enabled; }

    void Close() {
        if(m_handle != INVALID_HANDLE) {
            FileClose(m_handle);
            m_handle = INVALID_HANDLE;
        }
    }
};

#endif
