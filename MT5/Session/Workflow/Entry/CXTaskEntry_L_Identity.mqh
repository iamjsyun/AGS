#ifndef CX_TASK_ENTRY_L_IDENTITY_MQH
#define CX_TASK_ENTRY_L_IDENTITY_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXGuard.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_L_Identity
 * @brief [Logic] 신호의 정합성(Magic, SID) 검증
 */
class CXTaskEntry_L_Identity : public IXTask {
public:
    virtual string Name() override { return "Entry_L_Identity"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IXGuard* guard = CX_GET_OBJ(ctx, "guard", IXGuard);

        if(IS_INVALID(sig)) return TASK_BREAK;
        if(IS_INVALID(guard)) return TASK_CONTINUE; 

        if(!guard.ValidateMagic(sig.GetMagic())) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-L-ID", xp, StringFormat("Identity Violation: Invalid Magic %I64u", sig.GetMagic())));
            return TASK_BREAK;
        }

        if(!guard.ValidateSID(sig.GetSid())) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-L-ID", xp, "Identity Violation: Invalid SID Format"));
            return TASK_BREAK;
        }

        return TASK_CONTINUE;
    }
};

#endif
