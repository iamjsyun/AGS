#ifndef CX_TASK_ENTRY_P_INTENT_MQH
#define CX_TASK_ENTRY_P_INTENT_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_P_Intent
 * @brief [Persistence] 계산된 가격 정보 및 XE_PENDING_REQ 상태를 DB에 저장
 */
class CXTaskEntry_P_Intent : public IXTask {
public:
    virtual string Name() override { return "Entry_P_Intent"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        // 계산된 가격 정보(Exec, SL, TP)의 영속성을 보장하기 위해 최초 1회는 무조건 저장
        string sessionLockKey = StringFormat("IntentPersisted_%s", sig.GetSid());
        if(IS_VALID(ctx.Get(sessionLockKey))) {
            // [Muted] XP_LOG_TRACE(xp, CXAuditFormatter::Build("TASK-INTENT", xp, "SKIP: Intent already persisted in this session."));
            return TASK_CONTINUE;
        }

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("TASK-INTENT", xp, "Persisting Entry Intent to DB..."));
        
        // 1. 상태 및 메시지 업데이트 (Status는 유지하거나 PENDING_REQ로 강제)
        CXMessageProvider::UpdateStatus(sig, XE_PENDING_REQ, "Intent: Physical Order Requesting...");
        
        // 2. 전체 데이터 저장 (계산된 가격 정보 포함)
        repo.SaveSignal(sig);
        
        // 3. 세션 내 중복 저장 방지 락
        ctx.Set(sessionLockKey, new CXParam());

        XP_LOG_OK(xp, CXAuditFormatter::Build("TASK-INTENT", xp, "SUCCESS: Entry Intent Persisted."));

        return TASK_CONTINUE;
    }
};

#endif
