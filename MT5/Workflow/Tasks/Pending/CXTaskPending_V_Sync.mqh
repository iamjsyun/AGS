#ifndef CX_TASK_PENDING_V_SYNC_MQH
#define CX_TASK_PENDING_V_SYNC_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskPending_V_Sync
 * @brief [Verify] 터미널 실물 상태 동기화 및 외부 명령 감시
 */
class CXTaskPending_V_Sync : public IXTask {
public:
    virtual string Name() override { return "Pending_V_Sync"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        //--- [v14.34 Fix] Error-State Liquidation Bypass
        if(sig.GetXAExit() == XA_ACTIVE) {
            XP_LOG_INFO(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, "Exit command detected. Moving to LIQUIDATING."));
            return SESSION_LIQUIDATING;
        }



        // 1. 상태 동기화 (오더 -> 포지션 전환 감지)
        if(IS_VALID(invMgr)) {
            ulong ticket = (ulong)sig.GetTicket();
            if(ticket > 0 && invMgr.IsPositionExists(ticket)) {
                XP_LOG_OK(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, StringFormat("Order filled! Ticket:%I64u is now a Position.", ticket)));
                CXMessageProvider::UpdateStatus(sig, XE_EXECUTED, "Pending Order Filled");
                repo.UpdateStatus(sig);
                return SESSION_ACTIVE;
            }
        }

        if(sig.GetStatus() == XE_ERROR) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, "ABORT: Signal is in XE_ERROR."));
            return SESSION_ERROR;
        }

        if(sig.GetStatus() >= XE_EXECUTED) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, "Signal executed. Moving to ACTIVE."));
            return SESSION_ACTIVE;
        }
        
        if(sig.GetTicket() <= 0) {
            // [v14.15 Muted] XP_LOG_TRACE(xp, CXAuditFormatter::Build("PENDING-V-SYNC", xp, "Yield: No ticket yet."));
            return TASK_BREAK;
        }

        return TASK_CONTINUE;
    }
};

#endif
