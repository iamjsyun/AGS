#ifndef CXREMOTELOGGER_MQH
#define CXREMOTELOGGER_MQH

#include "..\Interfaces\ICXLogger.mqh"
#include "..\Interfaces\ICXConfig.mqh"

/**
 * @class CXRemoteLogger
 * @brief TCP 소켓을 통해 원격 서버로 로그를 전송
 */
class CXRemoteLogger : public ICXLogger {
private:
    int        m_socket;
    string     m_host;
    int        m_port;
    bool       m_enabled;
    string     m_sid;
    ICXLogger* m_diag; // 내부 진단용 로거

public:
    CXRemoteLogger(string sid, string host, int port, ICXLogger* diagLogger = NULL) 
        : m_socket(INVALID_HANDLE), m_sid(sid), m_host(host), m_port(port), m_enabled(true), m_diag(diagLogger) {
        Connect();
    }

    virtual ~CXRemoteLogger() {
        Disconnect();
    }

    void DiagLog(string msg, ENUM_LOG_LEVEL level = LOG_LVL_DEBUG) {
        string fullMsg = "[RemoteLog] " + msg;
        Print(fullMsg);
        if(IS_VALID(m_diag)) m_diag.Log(level, fullMsg);
    }

virtual void Log(ENUM_LOG_LEVEL level, string msg) override {
    if(!m_enabled || m_host == "") return;

    // 연결 확인 및 재접속 시도
    if(m_socket == INVALID_HANDLE) {
        DiagLog(StringFormat("Attempting to connect to %s:%d...", m_host, m_port));
        if(!Connect()) return;
    }

    string nlogLevel = MapToNLog(level);
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);

    // Log4View log4net XML Format Layout
    string xml = "<log4net:event logger=\"ATSE\" ";
    xml += "timestamp=\"" + timestamp + "\" ";
    xml += "level=\"" + nlogLevel + "\" ";
    xml += "thread=\"1\">\r\n";
    xml += "  <log4net:message>" + msg + "</log4net:message>\r\n";
    xml += "  <log4net:properties>\r\n";
    xml += "    <log4net:data name=\"sid\" value=\"" + m_sid + "\" />\r\n";
    xml += "  </log4net:properties>\r\n";
    xml += "</log4net:event>\r\n";

    uchar data[];
    StringToCharArray(xml, data, 0, WHOLE_ARRAY, CP_UTF8);

    uint sent = SocketSend(m_socket, data, (uint)ArraySize(data));

    if(sent == 0 || sent == (uint)-1) {
        DiagLog(StringFormat("Send failed. Socket closed. (sent:%u)", sent), LOG_LVL_ERROR);
        Disconnect();
    }
}

private:
string MapToNLog(ENUM_LOG_LEVEL level) {
    switch(level) {
        case LOG_LVL_TRACE: return "TRACE";
        case LOG_LVL_DEBUG: return "DEBUG";
        case LOG_LVL_INFO:  return "INFO";
        case LOG_LVL_OK:    return "INFO";
        case LOG_LVL_WARN:  return "WARN";
        case LOG_LVL_ERROR: return "ERROR";
        default:            return "INFO";
    }
}

    virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
    virtual bool IsEnabled() const override { return m_enabled; }

private:
    bool Connect() {
        if(m_host == "" || m_port <= 0) return false;

        m_socket = SocketCreate();
        if(m_socket == INVALID_HANDLE) {
            DiagLog(StringFormat("SocketCreate failed. Error: %d", GetLastError()), LOG_LVL_ERROR);
            return false;
        }

        // 5초 타임아웃으로 연결 시도
        if(!SocketConnect(m_socket, m_host, m_port, 5000)) {
            int err = GetLastError();
            string errMsg = StringFormat("Connection failed to %s:%d. Error: %d", m_host, m_port, err);
            
            if(err == 4014) {
                errMsg += " (HINT: Add '127.0.0.1' to WebRequest list)";
            }
            
            DiagLog(errMsg, LOG_LVL_ERROR);
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
            return false;
        }

        DiagLog(StringFormat("Connected successfully to %s:%d (Socket:%d)", m_host, m_port, m_socket), LOG_LVL_INFO);
        return true;
    }

    void Disconnect() {
        if(m_socket != INVALID_HANDLE) {
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
        }
    }
};

#endif
