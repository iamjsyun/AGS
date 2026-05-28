#ifndef CX_TASK_GUARD_V_VOLATILITY_MQH
#define CX_TASK_GUARD_V_VOLATILITY_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"

/**
 * @class CXTaskGuard_V_Volatility
 * @brief [Guard] 급격한 변동성 구간 진입 억제
 */
class CXTaskGuard_V_Volatility : public IXTask {
public:
    virtual string Name() override { return "Guard_V_Volatility"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        // 간단한 틱 간 변동성 체크 로직 (Placeholder)
        return TASK_CONTINUE;
    }
};

#endif
