#ifndef CXSESSIONTASK_MQH
#define CXSESSIONTASK_MQH

#include "..\Platform\Core\Interfaces\ICXTradingSession.mqh"
#include "..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\Platform\Core\Interfaces\ICXParam.mqh"
#include "..\Platform\Core\Interfaces\ICXContext.mqh"
#include "..\Platform\Core\Interfaces\ICXFluentSequence.mqh"
#include "..\Platform\Core\Sequence\CXSequenceOrchestrator.mqh"
#include "..\Platform\Core\Macros\CXMacros.mqh"
#include "..\Platform\Shared\Graphics\CXChartVisualizer.mqh"

/**
 * @class CXSessionTask
 * @brief [v18.30] 자산별 독립적 최적화 로직(TE/TS)을 수행하는 경량 실행 단위
 */
class CXSessionTask : public ICXTradingSession {
private:
    ICXContext*         m_ctx;
    ICXFluentSequence*  m_sequence;
    ICXSignal*          m_signal;
    string              m_sid;
    bool                m_isActive;

public:
    CXSessionTask(ICXContext* globalCtx, ICXSignal* sig) : m_isActive(true), m_signal(sig) {
        m_sid = sig.GetSid();
        m_ctx = globalCtx.CreateChildContext();
        if(IS_VALID(m_ctx)) {
            m_ctx.Register("signal", m_signal);
            
            // 시퀀스 생성 및 빌드
            m_sequence = new CXFluentSequence(m_ctx, "Task_" + m_sid);
            CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(globalCtx, "orchestrator", CXSequenceOrchestrator);
            if(IS_VALID(orchestrator)) {
                // 자산 타입에 따른 시퀀스 빌드 (Unit Task DSL 적용)
                orchestrator.BuildSessionSequence(m_sequence); 
            }
            m_sequence.Build();
        }
    }

    virtual ~CXSessionTask() {
        if(IS_VALID(m_signal)) {
            CXChartVisualizer::RemoveTEStart(m_ctx, m_signal);
        }
        SAFE_DELETE(m_sequence);
        SAFE_DELETE(m_ctx);
    }

    virtual string GetSid() const override { return m_sid; }
    virtual bool   IsActive() const override { return m_isActive; }
    virtual int    GetState() const override { return IS_VALID(m_sequence) ? m_sequence.State() : 99; }
    virtual ICXSignal* GetSignal() const override { return m_signal; }

    virtual void Start(ICXParam* xp) override {
        if(IS_VALID(m_sequence)) m_sequence.Pulse(xp);
    }

    virtual void Pulse(ICXParam* xp) override {
        if(!m_isActive || IS_INVALID(m_sequence)) return;
        
        xp.SetSignal(m_signal);
        xp.SetContext(m_ctx);
        
        m_sequence.Pulse(xp);
        
        // 종료 상태 도달 시 비활성화 (SYS_CLOSED=30)
        if(m_sequence.State() == 30 || m_sequence.State() == 99) {
            m_isActive = false;
        }
    }

    virtual void ForceTransition(int state) override {
        if(IS_VALID(m_sequence)) m_sequence.ForceState(state);
    }

    virtual void InjectState(ICXSignal* sig) override {
        // 복구 로직 (필요 시 구현)
    }
};

#endif
