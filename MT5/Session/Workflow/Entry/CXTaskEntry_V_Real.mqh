#ifndef CX_TASK_ENTRY_V_REAL_MQH
#define CX_TASK_ENTRY_V_REAL_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskEntry_V_Real
 * @brief [Verify] 터미널 내 실물 자산(Position/Order) 존재 확인 및 데이터 동기화
 */
class CXTaskEntry_V_Real : public IXTask {
public:
    virtual string Name() override { return "Entry_V_Real"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        
        if(IS_INVALID(sig) || IS_INVALID(invMgr)) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-V-REAL", xp, "FAILED: Required services missing."));
            return TASK_BREAK;
        }

        // [v14.34 Exit-First Priority]
        if(sig.GetXAExit() == XA_ACTIVE) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("ENTRY-V-REAL", xp, "ABORT: Exit intent detected. Redirecting to LIQUIDATING."));
            return SESSION_LIQUIDATING;
        }

        ulong ticket = (ulong)sig.GetTicket();
        bool exists = invMgr.IsPositionExists(ticket) || invMgr.IsOrderExists(ticket);

        if(!exists) {
            string retryKey = StringFormat("VRealRetry_%I64u", ticket);
            int retryCount = 0;
            ICXParam* pOld = ctx.GetParam(retryKey);
            if(IS_VALID(pOld)) retryCount = pOld.GetInt();

            string reason = "";
            int histStatus = invMgr.CheckHistoryClosure(ticket, reason);
            if(histStatus != XE_UNKNOWN) {
                XP_LOG_WARN(xp, CXAuditFormatter::Build("ENTRY-V-REAL", xp, StringFormat("ABORT: Asset in history as %d (%s).", histStatus, reason)));
                IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
                CXMessageProvider::UpdateStatus(sig, histStatus, reason);
                if(IS_VALID(repo)) repo.UpdateStatus(sig);
                return SESSION_LIQUIDATING;
            }

            if(IsTimedOut()) {
                string timeoutErr = StringFormat("Ticket(%I64u) Verification Timeout.", ticket);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-V-REAL", xp, "FAILED: " + timeoutErr));
                if(IS_VALID(xp)) xp.SetString("[ENTRY-V-REAL] " + timeoutErr);
                return SESSION_ERROR;
            }

            retryCount++;
            CXParam* pNew = new CXParam();
            pNew.SetInt(retryCount);
            ctx.Set(retryKey, pNew);
            
            IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
            CXMessageProvider::UpdateStatus(sig, XE_IN_TRANSIT, StringFormat("Verifying Asset... (Retry:%d)", retryCount));
            if(IS_VALID(repo)) repo.UpdateStatus(sig);

            return TASK_YIELD;
        }

        invMgr.SyncToSignal(sig);
        XP_LOG_OK(xp, CXAuditFormatter::Build("ENTRY-V-REAL", xp, StringFormat("SUCCESS: Ticket(%I64u) Confirmed.", ticket)));

        return TASK_CONTINUE;
    }
};

#endif
