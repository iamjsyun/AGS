#ifndef CX_TASK_ENTRY_V_TICKET_MQH
#define CX_TASK_ENTRY_V_TICKET_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXMessageProvider.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_V_Ticket
 * @brief [Verify] 티켓 번호 획득 및 과도기 상태 검증
 */
class CXTaskEntry_V_Ticket : public IXTask {
public:
    virtual string Name() override { return "Entry_V_Ticket"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        // [v14.34 Exit-First Priority]
        if(sig.GetXAExit() == XA_ACTIVE) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("ENTRY-V-TICKET", xp, "ABORT: Exit intent detected. Redirecting to LIQUIDATING."));
            return SESSION_LIQUIDATING;
        }

        ulong ticket = sig.GetTicket();
        XP_LOG_TRACE(xp, CXAuditFormatter::Build("ENTRY-V-TICKET", xp, StringFormat("Verifying Acquisition: [Ticket:%I64u]", ticket)));

        if(ticket <= 0) {
            if(IsTimedOut()) {
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-V-TICKET", xp, "FAILED: Ticket Acquisition Timeout."));
                return SESSION_ERROR;
            }
            // [v14.18 Muted] XP_LOG_DEBUG(xp, CXAuditFormatter::Build("ENTRY-V-TICKET", xp, "Yield: Waiting for ticket..."));
            return TASK_YIELD;
        }

        XP_LOG_OK(xp, CXAuditFormatter::Build("ENTRY-V-TICKET", xp, StringFormat("SUCCESS: Ticket %I64u Obtained.", ticket)));
        
        // [v18.17 Status Sync] 티켓 획득 즉시 XE_EXECUTED(10) 상태로 업데이트
        CXMessageProvider::UpdateStatus(sig, XE_EXECUTED, StringFormat("Ticket %I64u Obtained. Sequence Active.", ticket));
        
        // [v18.16 Persistence Fix] 획득된 티켓 번호를 DB에 즉시 동기화
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        if(IS_VALID(repo)) repo.UpdateStatus(sig);
        
        return TASK_CONTINUE;
    }
};

#endif
