#ifndef IXTASK_MQH
#define IXTASK_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXContext.mqh"

// Constants for controlling task execution results
#define TASK_CONTINUE   -1  // Proceed to the next task
#define TASK_BREAK      -2  // Maintain current state and interrupt chain execution (terminate current tick)
#define TASK_YIELD      -3  // Asynchronous wait. Maintain current state but re-execute in the next tick

/**
 * @interface IXTask
 * @brief Interface for atomic tasks performing a single responsibility within a sequence stage
 * [v2.1 Smart PVB] Added GetRequiredServices for dependency contract
 */
class IXTask : public CObject {
protected:
    int m_maxRetries;
    int m_retryCount;
    int m_timeoutSeconds;
    datetime m_startTime;
    bool m_isBound;

public:
    IXTask() : m_maxRetries(0), m_retryCount(0), m_timeoutSeconds(0), m_startTime(0), m_isBound(false) {}
    virtual ~IXTask() {}

    virtual string Name() = 0;
    
    /**
     * @brief [v2.0] Dependency injection and caching verification
     */
    virtual bool Bind(ICXContext* ctx) { return m_isBound = true; }
    
    /**
     * @brief [v2.1] Returns a list of service keywords required by this task (Smart PVB)
     * @details Example: "repo, asset_mgr"
     */
    virtual string GetRequiredServices() { return ""; }

    /**
     * @brief Execute task logic
     */
    virtual int Execute(ICXParam* xp, ICXContext* ctx) = 0;

    //-- Property management
    void SetMaxRetries(int r) { m_maxRetries = r; }
    void SetTimeout(int s) { m_timeoutSeconds = s; }
    
    int  GetRetryCount() const { return m_retryCount; }
    void IncrementRetry() { m_retryCount++; }
    void ResetRetry() { m_retryCount = 0; m_startTime = 0; }
    
    bool IsTimedOut() {
        if(m_timeoutSeconds <= 0) return false;
        if(m_startTime == 0) m_startTime = TimeCurrent();
        bool timedOut = (TimeCurrent() - m_startTime >= m_timeoutSeconds);
        if(timedOut) ResetRetry();
        return timedOut;
    }

    bool IsMaxRetriesExceeded() const {
        return (m_maxRetries > 0 && m_retryCount >= m_maxRetries);
    }
};

#endif
