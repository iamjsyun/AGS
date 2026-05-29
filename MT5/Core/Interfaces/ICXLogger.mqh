#ifndef ICXLOGGER_MQH
#define ICXLOGGER_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"
#include "ICXParam.mqh"
#include "ICXSignal.mqh"

/**
 * @enum ENUM_LOG_POLICY
 * @brief 로그 출력 정책 (Spam 방지용)
 */
enum ENUM_LOG_POLICY {
    LOG_POLICY_ALWAYS = 0,    // 무조건 출력
    LOG_POLICY_ON_CHANGE = 1  // 이전과 내용이 다를 때만 출력
};

/**
 * @class ICXLogger
 * @brief 멀티 채널 로깅을 위한 공용 인터페이스 및 베이스 클래스
 */
class ICXLogger : public CObject {
protected:
    string  m_history[2];     // [v12.1] 메시지 히스토리 (A-B-A-B 패턴 방지)
    int     m_repeat_count;   // 동일/교차 패턴 반복 횟수
    datetime m_last_log_time; // 마지막 로그 출력 시간
    
public:
    ICXLogger() : m_repeat_count(0), m_last_log_time(0) {
        m_history[0] = ""; m_history[1] = "";
    }
    virtual ~ICXLogger() override {}
    
    virtual void Log(ENUM_LOG_LEVEL level, string msg) = 0;
    virtual void SetEnabled(bool enabled) = 0;
    virtual bool IsEnabled() const = 0;

    /**
     * @brief [v12.1] 지능형 중복 방지 필터
     * @details 단순 중복뿐 아니라 A-B-A-B 교차 패턴도 필터링한다.
     */
    virtual bool ShouldLog(string msg, ENUM_LOG_POLICY policy) {
        if(policy == LOG_POLICY_ALWAYS) {
            m_repeat_count = 0;
            return true;
        }

        // 1. 완전 중복 또는 교차 중복 (A-B-A-B) 체크
        bool is_match = (msg == m_history[0] || msg == m_history[1]);
        
        if(is_match) {
            m_repeat_count++;
            // 처음 1회는 출력, 이후 5회까지는 침묵, 그 뒤에 한 번씩 생존 보고
            if(m_repeat_count > 1 && m_repeat_count % 10 != 0) return false;
            
            // 너무 빈번한 출력 방지 (최소 1초 간격)
            if(TimeCurrent() - m_last_log_time < 1) return false;
        } else {
            // 완전히 새로운 메시지 유입 시 히스토리 갱신
            m_repeat_count = 0;
            m_history[1] = m_history[0];
            m_history[0] = msg;
        }

        m_last_log_time = TimeCurrent();
        return true;
    }

    //-- Convenience methods for CXParam-based logging
    virtual void Trace(ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE) { Dispatch(LOG_LVL_TRACE, xp, msg, policy); }
    virtual void Info(ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE)  { Dispatch(LOG_LVL_INFO, xp, msg, policy); }
    virtual void Debug(ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE) { Dispatch(LOG_LVL_DEBUG, xp, msg, policy); }
    virtual void Warn(ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE)  { Dispatch(LOG_LVL_WARN, xp, msg, policy); }
    virtual void Error(ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ALWAYS)    { Dispatch(LOG_LVL_ERROR, xp, msg, policy); }
    virtual void Ok(ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ALWAYS)       { Dispatch(LOG_LVL_OK, xp, msg, policy); }

    virtual void Dispatch(ENUM_LOG_LEVEL level, ICXParam* xp, string msg, ENUM_LOG_POLICY policy = LOG_POLICY_ON_CHANGE) {
        string sid_str = "";
        if(CheckPointer(xp) != POINTER_INVALID) {
            ICXSignal* sig = xp.GetSignal();
            if(CheckPointer(sig) != POINTER_INVALID) sid_str = sig.GetSid();
        }
        string prefix = (sid_str != "") ? "[" + sid_str + "] " : "";
        string final_msg = prefix + msg;
        
        if(ShouldLog(final_msg, policy)) {
            Log(level, final_msg);
        }
    }
};

#endif
