#ifndef CXSTAGESYSTEMSETUP_MQH
#define CXSTAGESYSTEMSETUP_MQH

#include "..\..\Core\Interfaces\IXStage.mqh"
#include "..\..\Core\Interfaces\ICXConfig.mqh"
#include "..\..\Core\Interfaces\ICXLogger.mqh"
#include "..\..\Core\Interfaces\ICXSequenceOrchestrator.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"

/**
 * @class CXStageSystemSetup
 * @brief [v18.32] 시스템 기동 초기화 및 로그 환경 설정을 검증하는 부트스트랩 단계
 */
class CXStageSystemSetup : public IXStage {
private:
    ICXSequenceOrchestrator* m_orchestrator;

public:
    CXStageSystemSetup() : m_orchestrator(NULL) {}
    virtual ~CXStageSystemSetup() {}

    virtual string Name() override { return "Stage_SystemSetup"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_orchestrator = CX_GET_OBJ(ctx, "orchestrator", ICXSequenceOrchestrator);
        if(IS_INVALID(m_orchestrator)) return false;
        return IXStage::Bind(ctx);
    }

    virtual bool OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) override {
        // 부트스트랩은 기동 시 1회만 수행 (별도 조건 없음)
        return true;
    }

    virtual int OnProcess(ICXParam* xp, ICXContext* ctx) override {
        // [v18.42] 부트스트랩 로그는 CXAppService::Initialize()에서 동시 출력을 위해 선처리됨.
        // 이 스테이지는 시스템이 준비되었음을 확인하는 라우팅 게이트웨이 역할만 수행.
        return m_orchestrator.ResolveId("WATCHER_ENTRY_DISCOVERY");
    }

    virtual void OnEnter(ICXContext* ctx) override {}
    virtual void OnExit(ICXContext* ctx) override {}
};

#endif
