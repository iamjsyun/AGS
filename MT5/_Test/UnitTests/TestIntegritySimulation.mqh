#ifndef TEST_INTEGRITY_SIMULATION_MQH
#define TEST_INTEGRITY_SIMULATION_MQH

#include "..\..\Core\Sequence\CXSequenceOrchestrator.mqh"
#include "..\..\Core\Sequence\CXFluentSequence.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Core\Models\CXParam.mqh"
#include "..\..\Core\Interfaces\IXStage.mqh"

/**
 * @class MockYieldStage
 * @brief 시뮬레이션을 위해 강제로 TASK_YIELD 또는 에러를 반환하는 가짜 스테이지
 */
class MockYieldStage : public IXStage {
private:
    int m_failCount;
    int m_currentCount;
    int m_returnState;

public:
    MockYieldStage(int failAt, int returnState) : m_failCount(failAt), m_currentCount(0), m_returnState(returnState) {}
    virtual string Name() override { return "MockYieldStage"; }
    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        m_currentCount++;
        if(m_currentCount <= m_failCount) return m_returnState; // Fail (if_false path)
        return 10; // Success (Success path)
    }
    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override { return true; }
    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

class TestIntegritySimulation {
public:
    static bool Run() {
        Print("--- Running TestIntegritySimulation ---");
        bool allPassed = true;
        
        // 1. Retry Mechanism Test
        {
            CXContext ctx;
            CXParam xp;
            xp.SetContext(GetPointer(ctx));
            CXFluentSequence seq(GetPointer(ctx), "RetryTest");

            // From 0, Execute Mock (Fail 2 times), Success 10, Fail 99, Retries 3
            // if_false(fail path)로 가더라도 리트라이 횟수가 남았으면 스테이트 유지
            seq.From(0)
               .Execute(new MockYieldStage(2, 99)) // 2번 실패(99 반환)
               .OnSuccess(10)
               .OnFail(99)
               .Retries(3)
               .Build();

            // Pulse 1: Fail 1 (Retry 1/3)
            seq.Pulse(GetPointer(xp));
            if(seq.State() == 0) Print("  [PASS] Retry 1: State maintained at 0.");
            else { PrintFormat("  [FAIL] Retry 1: State moved to %d", seq.State()); allPassed = false; }

            // Pulse 2: Fail 2 (Retry 2/3)
            seq.Pulse(GetPointer(xp));
            if(seq.State() == 0) Print("  [PASS] Retry 2: State maintained at 0.");
            else { PrintFormat("  [FAIL] Retry 2: State moved to %d", seq.State()); allPassed = false; }

            // Pulse 3: Success (Mock now returns 10)
            seq.Pulse(GetPointer(xp));
            if(seq.State() == 10) Print("  [PASS] Retry 3: Success after retries. Moved to 10.");
            else { PrintFormat("  [FAIL] Retry 3: Failed to move to 10. Current: %d", seq.State()); allPassed = false; }
        }

        // 2. Circuit Breaker Test (Exhaust Retries)
        {
            CXContext ctx;
            CXParam xp;
            xp.SetContext(GetPointer(ctx));
            CXFluentSequence seq(GetPointer(ctx), "CircuitBreakerTest");

            seq.From(0)
               .Execute(new MockYieldStage(10, 99)) // 계속 실패
               .OnSuccess(10)
               .OnFail(99)
               .Retries(2)
               .Build();

            seq.Pulse(GetPointer(xp)); // Fail 1 (Retry 1/2)
            seq.Pulse(GetPointer(xp)); // Fail 2 (Retry 2/2)
            seq.Pulse(GetPointer(xp)); // Fail 3 (Exhausted) -> Move to Fail State (99)

            if(seq.State() == 99) Print("  [PASS] Circuit Breaker: Moved to 99 after retries exhausted.");
            else { PrintFormat("  [FAIL] Circuit Breaker: Expected state 99, got %d", seq.State()); allPassed = false; }
        }

        return allPassed;
    }
};

#endif
