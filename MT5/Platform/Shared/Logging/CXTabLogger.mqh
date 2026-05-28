#ifndef CXTABLOGGER_MQH
#define CXTABLOGGER_MQH

#include "..\..\Core\Interfaces\ICXLogger.mqh"

/**
 * @class CXTabLogger
 * @brief MT5 터미널 전문가(Experts) 탭에 로그를 출력
 */
class CXTabLogger : public ICXLogger {
private:
    bool m_enabled;

public:
    CXTabLogger() : m_enabled(true) {}
    virtual ~CXTabLogger() {}

    virtual void Log(ENUM_LOG_LEVEL level, string msg) override {
        if(!m_enabled) return;
        PrintFormat("[%s] %s", EnumToString(level), msg);
    }

    virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
    virtual bool IsEnabled() const override { return m_enabled; }
};

#endif
