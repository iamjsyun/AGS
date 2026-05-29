#ifndef IXTASK_MQH
#define IXTASK_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXContext.mqh"

// Task 실행 결과 제어 상수
#define TASK_CONTINUE   -1  // 다음 태스크로 진행
#define TASK_BREAK      -2  // 현재 상태 유지하고 체인 실행 중단 (이번 틱 종료)
#define TASK_YIELD      -3  // 비차단 대기: 현재 상태를 유지하되 다음 틱에서 재시도

/**
 * @interface IXTask
 * @brief 시퀀스 스테이지(Stage) 내부에서 단일 책임을 수행하는 원자적 태스크 인터페이스
 * [v9.9.2] Hyper-Atomization을 위한 상태 제어 상수 및 프로퍼티 확장
 */
class IXTask : public CObject {
protected:
    int m_maxRetries;
    int m_retryCount;
    int m_timeoutSeconds;
    datetime m_startTime;

public:
    IXTask() : m_maxRetries(0), m_retryCount(0), m_timeoutSeconds(0), m_startTime(0) {}
    virtual ~IXTask() {}

    virtual string Name() = 0;
    
    /**
     * @brief 태스크 로직 실행
     * @return 양수(상태 코드): 즉시 해당 상태로 시퀀스 전이 발생
     *         TASK_CONTINUE: 다음 태스크로 흐름을 넘김
     *         TASK_BREAK: 태스크 체인 실행을 멈추고 현재 상태를 유지함
     *         TASK_YIELD: 비차단 대기 (다음 틱에서 해당 태스크부터 다시 시작)
     */
    virtual int Execute(ICXParam* xp, ICXContext* ctx) = 0;

    //-- 속성 관리
    void SetMaxRetries(int r) { m_maxRetries = r; }
    void SetTimeout(int s) { m_timeoutSeconds = s; }
    
    int  GetRetryCount() const { return m_retryCount; }
    void IncrementRetry() { m_retryCount++; }
    void ResetRetry() { m_retryCount = 0; m_startTime = 0; }
    
    bool IsTimedOut() {
        if(m_timeoutSeconds <= 0) return false;
        if(m_startTime == 0) m_startTime = TimeCurrent();
        bool timedOut = (TimeCurrent() - m_startTime >= m_timeoutSeconds);
        if(timedOut) ResetRetry(); // 타임아웃 발생 시 상태 초기화 (재시도 루프 종료용)
        return timedOut;
    }

    bool IsMaxRetriesExceeded() const {
        return (m_maxRetries > 0 && m_retryCount >= m_maxRetries);
    }
};

#endif
