#ifndef ICXSEQUENCEORCHESTRATOR_MQH
#define ICXSEQUENCEORCHESTRATOR_MQH

#include <Object.mqh>

/**
 * @interface ICXSequenceOrchestrator
 * @brief 시퀀스 명칭 기반 ID 확인 및 구성을 위한 인터페이스
 */
class ICXSequenceOrchestrator : public CObject {
public:
    virtual ~ICXSequenceOrchestrator() {}
    virtual int  ResolveId(string value) = 0;
    virtual bool Bind(ICXContext* ctx) = 0; // [v2.0]
};

#endif
