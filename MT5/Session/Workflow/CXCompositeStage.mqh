#ifndef CXCOMPOSITESTAGE_MQH
#define CXCOMPOSITESTAGE_MQH

#include "..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include <Arrays\ArrayObj.mqh>


/**
 * @class CXCompositeStage
 * @brief 여러 개의 IXTask(마이크로 태스크)를 조립하여 순차 실행하는 복합 시퀀스 스테이지
 */
class CXCompositeStage : public IXStage {
private:
    string      m_name;
    IXTask*     m_taskPtrs[];       // [v15.2] Typed Pointer Array
    int         m_taskCount;
    int         m_currentTaskIndex; 
    bool        m_hasConditionFunc;

public:
    CXCompositeStage(string name) : m_name(name), m_taskCount(0), m_currentTaskIndex(0), m_hasConditionFunc(false) {
        ArrayResize(m_taskPtrs, 0, 10);
    }

    virtual ~CXCompositeStage() {
        for(int i=0; i<m_taskCount; i++) {
            SAFE_DELETE(m_taskPtrs[i]);
        }
        ArrayResize(m_taskPtrs, 0);
    }

    virtual string Name() override { return m_name; }

    /**
     * @brief 실행할 태스크를 체인에 추가합니다.
     */
    CXCompositeStage* AddTask(IXTask* task) {
        if(IS_VALID(task)) {
            m_taskCount++;
            ArrayResize(m_taskPtrs, m_taskCount);
            m_taskPtrs[m_taskCount-1] = task;
        }
        return GetPointer(this);
    }

    /**
     * @brief 기본적으로 true를 반환하며, 태스크 내부 로직에서 조건을 필터링합니다.
     */
    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        return true; 
    }

    /**
     * @brief 등록된 태스크들을 순차적으로 실행
     */
    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        // [v15.2 Typed Accessor] Eliminate dynamic_cast
        string indexKey = StringFormat("CompositeIndex_%s", m_name);
        ICXParam* pIdx = ctx.GetParam(indexKey);
        int startIndex = IS_VALID(pIdx) ? pIdx.GetInt() : 0;
        
        for(int i = 0; i < m_taskCount; i++) {
            // [v14.3 Priority Execution] 
            // 인덱스 0번 태스크(보통 IntentWatch)는 이전의 Yield 지점과 상관없이 "매 틱 무조건 실행"
            if(i > 0 && i < startIndex) continue; 

            IXTask* task = m_taskPtrs[i];
            if(IS_VALID(task)) {
                // [v9.9.2] 타임아웃 검증
                if(task.IsTimedOut()) {
                    string timeoutErr = StringFormat("[%s] Task Timeout. Moving to SESSION_ERROR.", task.Name());
                    XP_LOG_ERROR(xp, CXAuditFormatter::Build("COMPOSITE-ERR", xp, timeoutErr));
                    if(IS_VALID(xp)) xp.SetString(timeoutErr);
                    if(IS_VALID(pIdx)) pIdx.SetInt(0);
                    return SESSION_ERROR;
                }

                // [v14.9 Muted] 태스크 실행 전 트레이싱 로그 출력
                // XP_LOG_TRACE(xp, CXAuditFormatter::Build("COMPOSITE-TRACE", xp, "Executing Task: " + task.Name()));

                int res = task.Execute(xp, ctx);
                
                // [v14.48 Muted] Log task result
                // if(res != TASK_CONTINUE) {
                //     XP_LOG_TRACE(xp, CXAuditFormatter::Build("COMPOSITE-TRACE", xp, StringFormat("Task %s returned result: %d", task.Name(), res)));
                // }

                // 1. 특정 상태로 전이 지시 시 즉시 반환 (성공/상태변경)
                if(res >= 0) {
                    task.ResetRetry(); 
                    if(IS_VALID(pIdx)) pIdx.SetInt(0);
                    return res;
                }
                // 2. 실행 중지(Break) 지시 시 남은 태스크 무시하고 현재 상태 유지
                else if(res == TASK_BREAK) {
                    if(IS_VALID(pIdx)) pIdx.SetInt(0);
                    return STATE_UNCHANGED;
                }
                // 3. 비차단 대기(Yield) 시 인덱스 유지하고 다음 틱 대기
                else if(res == TASK_YIELD) {
                    if(IS_INVALID(pIdx)) {
                        pIdx = xp.CreateEmptyParam(); // [v15.2] Create via param factory if needed
                        ctx.Set(indexKey, pIdx);
                    }
                    pIdx.SetInt(i); // 현재 지점 저장
                    
                    task.IncrementRetry();
                    if(task.IsMaxRetriesExceeded()) {
                        string retryErr = StringFormat("[%s] Max Retries Exceeded. Moving to SESSION_ERROR.", task.Name());
                        XP_LOG_ERROR(xp, CXAuditFormatter::Build("COMPOSITE-ERR", xp, retryErr));
                        if(IS_VALID(xp)) xp.SetString(retryErr);
                        pIdx.SetInt(0);
                        return SESSION_ERROR;
                    }
                    // Yield 발생 시 0번(감시자)은 다음 틱에도 실행되어야 하므로 루프 종료
                    return STATE_UNCHANGED;
                }
                // 4. TASK_CONTINUE(-1) 시 다음 태스크로 진행
                else if(res == TASK_CONTINUE) {
                    task.ResetRetry(); 
                }
            }
        }
        
        if(IS_VALID(pIdx)) pIdx.SetInt(0);
        return STAGE_SUCCESS; 
    }

    virtual void OnEnter(ICXContext* ctx) override {
        string indexKey = StringFormat("CompositeIndex_%s", m_name);
        ICXParam* pIdx = ctx.GetParam(indexKey);
        if(IS_INVALID(pIdx)) {
            // Need a way to create param without knowing concrete type
            // For now, if null, it will be created in OnProcess
        } else {
            pIdx.SetInt(0);
        }
        XP_LOG_DEBUG(NULL, StringFormat("[%s] Composite Stage Entered (%d tasks)", m_name, m_taskCount));
    }
    
    virtual void OnExit(ICXContext* ctx) override {
        string indexKey = StringFormat("CompositeIndex_%s", m_name);
        ICXParam* pIdx = ctx.GetParam(indexKey);
        if(IS_VALID(pIdx)) pIdx.SetInt(0);
        XP_LOG_DEBUG(NULL, StringFormat("[%s] Composite Stage Exited", m_name));
    }
};

#endif
