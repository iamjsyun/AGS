#ifndef CX_TASK_INTENT_WATCH_MQH
#define CX_TASK_INTENT_WATCH_MQH

#include "..\..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\Core\Macros\CXMacros.mqh"
#include "..\..\..\Core\Logger\CXMessageProvider.mqh"
#include "..\..\..\Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskIntentWatch
 * @brief 외부 강제 청산 의도 모니터링
 */
class CXTaskIntentWatch : public IXTask {
public:
    virtual string Name() override { return "Task_IntentWatch"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);
        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        
        if(IS_INVALID(sig) || IS_INVALID(repo)) return TASK_BREAK;

        // [v14.3 Fast-Path] 터미널 수동 청산 감지 (좀비 세션 방지) -> [v16.11 Fast-Track Mandate]
        ulong ticket = (ulong)sig.GetTicket();
        if(ticket > 0 && IS_VALID(invMgr)) {
            if(!invMgr.IsAssetExists(ticket, sig.GetType())) {
                string manualCloseMsg = StringFormat("Manual Close Detected: Physical Asset(%I64u) disappeared.", ticket);
                XP_LOG_WARN(xp, CXAuditFormatter::Build("INTENT-WATCH", xp, manualCloseMsg));
                
                // 직권으로 xe_status=24 및 xa_exit=2 동시 마킹하여 즉시 종료 확정
                sig.SetStatus(XE_CLOSED_MANUAL);
                sig.SetXAExit(XA_CLOSED_COMPLETED);
                sig.SetStatusMsg(manualCloseMsg);
                
                // [v16.19] Use ForceUpdateIntent to explicitly override DB values (Bypass MAX guard)
                if(IS_VALID(repo)) repo.ForceUpdateIntent(sig);
                
                return SESSION_CLOSED; // 즉시 세션 완전 종료 (SESSION_CLOSED)
            }
        }

        // [v14.1 Real-time Sync] DB에서 최신 신호 상태 재획득
        ICXSignal* fresh = repo.GetSignalBySid(sig.GetSid());
        if(IS_VALID(fresh)) {
            // 외부에서의 청산 의도 주입 확인
            if(fresh.GetXAExit() == XA_ACTIVE && sig.GetXAExit() != XA_ACTIVE) {
                sig.SetXAExit(XA_ACTIVE);
                XP_LOG_INFO(xp, CXAuditFormatter::Build("INTENT-WATCH", xp, "External Exit Intent Synchronized from DB."));
            }
            
            delete fresh;
        }

        // 동기화된 의도에 따라 전이 결정
        if(sig.GetXAExit() == XA_ACTIVE) {
            return SESSION_LIQUIDATING; // 상태 20으로 전이
        }

        return TASK_CONTINUE;
    }
};

#endif
