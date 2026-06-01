#ifndef CXSESSIONTASK_MQH
#define CXSESSIONTASK_MQH

#include "..\..\01_Core\Interfaces\ICXTradingSession.mqh"
#include "..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\01_Core\Interfaces\ICXParam.mqh"
#include "..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\01_Core\Interfaces\ICXFluentSequence.mqh"
#include "..\..\06_Orchestration\Sequence\CXSequenceOrchestrator.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\01_Core\UI\CXChartVisualizer.mqh"

/**
 * @class CXSessionTask
 * @brief [v18.30] Lightweight execution unit that performs independent optimization logic (TE/TS) per asset
 */
class CXSessionTask : public ICXTradingSession {
private:
    ICXContext*         m_ctx;
    ICXLogger*          m_sessionLogger; // [v2.2] Dedicated SID Logger
    ICXFluentSequence*  m_sequence;
    ICXSignal*          m_signal;
    string              m_sid;
    bool                m_isActive;

public:
    CXSessionTask(ICXContext* globalCtx, ICXSignal* sig) : m_isActive(true), m_signal(sig), m_sessionLogger(NULL) {
        m_sid = sig.GetSid();
        m_ctx = globalCtx.CreateChildContext();
        if(IS_VALID(m_ctx)) {
            m_ctx.Register("signal", m_signal);
            
            // [v2.2] Session-specific Logger Injection
            ICXServiceFactory* factory = CX_GET_OBJ(globalCtx, "factory", ICXServiceFactory);
            ICXConfig* config = globalCtx.GetConfig();
            if(IS_VALID(factory) && IS_VALID(config)) {
                m_sessionLogger = factory.CreateLogger(m_sid, config);
                if(IS_VALID(m_sessionLogger)) {
                    m_ctx.Register("logger", m_sessionLogger, true); // Override global logger in this child context
                }
            }

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

    virtual bool Bind() override {
        return (IS_VALID(m_sequence)) ? m_sequence.Bind() : false;
    }

    virtual void Start(ICXParam* xp) override {
        if(IS_VALID(m_sequence)) {
            xp.SetSignal(m_signal);
            xp.SetContext(m_ctx);
            m_sequence.Pulse(xp);
            
            // [v11.4 Mandate] Dangling Pointer Protection
            xp.SetSignal(NULL);
            xp.SetContext(NULL);
        }
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

        // [v11.4 Mandate] Dangling Pointer Protection
        if(IS_VALID(xp)) {
            xp.SetSignal(NULL);
            xp.SetContext(NULL);
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
