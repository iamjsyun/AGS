#ifndef CXFILELOGGER_MQH
#define CXFILELOGGER_MQH

#include "..\Interfaces\ICXLogger.mqh"

/**
 * @class CXFileLogger
 * @brief 세션별 독립 로그 파일 생성 및 기록 담당
 */
class CXFileLogger : public ICXLogger {
private:
    int    m_handle;
    string m_filename;
    string m_sid;
    int    m_lastHour;
    bool   m_enabled;

public:
    CXFileLogger() : m_handle(INVALID_HANDLE), m_lastHour(-1), m_enabled(true) {}
    ~CXFileLogger() { Close(); }

    /**
     * @brief {sid}-{yymmdd-HH}.log 형식으로 파일 초기화 (시간 단위 생성)
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

        // [v14.44] Using Unicode for consistent multilingual support
        string line = StringFormat("[%s] [%s] %s\r\n", EnumToString(level), TimeToString(TimeCurrent(), TIME_SECONDS), msg);
        FileWriteString(m_handle, line);
        FileFlush(m_handle);
    }

private:
    bool OpenByTime(MqlDateTime &dt, bool truncate) {
        Close();

        if(!FolderCreate("AGS", FILE_COMMON)) {
            int err = GetLastError();
            if(err != 0 && err != 5019) PrintFormat("[LOG-ERR] FolderCreate AGS failed. Code:%d", err);
        }

        string timestamp = StringFormat("%02d%02d%02d-%02d0000", dt.year % 100, dt.mon, dt.day, dt.hour);
        m_filename = StringFormat("AGS\\%s-%s.log", m_sid, timestamp);
        
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
        
        PrintFormat("[LOG-CRITICAL] Failed to create log file! Path: AGS\\%s, SID: %s, Error: %d", 
                    m_filename, m_sid, GetLastError());
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
