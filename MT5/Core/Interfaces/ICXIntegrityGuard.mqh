#ifndef ICXINTEGRITYGUARD_MQH
#define ICXINTEGRITYGUARD_MQH

#include <Object.mqh>
#include "ICXContext.mqh"
#include "ICXSequenceOrchestrator.mqh"

/**
 * @interface ICXIntegrityGuard
 * @brief [v2.1] 시스템 조립 무결성 전수 검사 인터페이스
 */
class ICXIntegrityGuard : public CObject {
public:
    virtual ~ICXIntegrityGuard() {}
    
    /**
     * @brief 조립 무결성 전수 검사 실행
     */
    virtual bool Inspect(ICXContext* globalCtx, ICXSequenceOrchestrator* orchestrator) = 0;
    
    /**
     * @brief 기동 전 환경(파일 및 확장자) 선제 검증
     */
    virtual bool AuditEnvironment(string scenarioFile) = 0;
    
    /**
     * @brief 검사 결과 상세 리포트 획득
     */
    virtual string GetDetailedReport() const = 0;
};

#endif
