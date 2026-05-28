#ifndef CX_TASK_FINALIZE_V_DOUBLECHECK_MQH
#define CX_TASK_FINALIZE_V_DOUBLECHECK_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"

/**
 * @class CXTaskFinalize_V_DoubleCheck
 * @brief [Verify] DB 최종 기록 전 터미널 티켓 교차 검증
 */
class CXTaskFinalize_V_DoubleCheck : public IXTask {
public:
    virtual string Name() override { return "Finalize_V_DoubleCheck"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket <= 0) return TASK_BREAK;

        XP_LOG_TRACE(xp, CXAuditFormatter::Build("FINAL-V-CHECK", xp, StringFormat("Double-Checking Ticket:%I64u", ticket)));

        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(invMgr) || !invMgr.IsAssetExists(ticket, sig.GetType())) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("FINAL-V-CHECK", xp, StringFormat("FAILED: Phantom Ticket:%I64u", ticket)));
            return TASK_BREAK;
        }

        XP_LOG_OK(xp, CXAuditFormatter::Build("FINAL-V-CHECK", xp, "SUCCESS: Ticket verified."));
        return TASK_CONTINUE;
    }
};

#endif
