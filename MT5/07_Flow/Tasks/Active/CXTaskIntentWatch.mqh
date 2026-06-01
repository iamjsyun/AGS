#ifndef CX_TASK_INTENT_WATCH_MQH
#define CX_TASK_INTENT_WATCH_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXMessageProvider.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskIntentWatch
 * @brief Monitoring for external forced liquidation intent
 * [v2.1 Smart PVB] Implement GetRequiredServices
 */
class CXTaskIntentWatch : public IXTask {
private:
    IRepository*     m_repo;
    ICXAssetManager* m_assetMgr;

public:
    CXTaskIntentWatch() : m_repo(NULL), m_assetMgr(NULL) {}
    virtual string Name() override { return "Task_IntentWatch"; }
    
    virtual string GetRequiredServices() override { return "repo, asset_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_repo   = CX_GET_OBJ(ctx, "repo", IRepository);
        m_assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        return (m_repo != NULL && m_assetMgr != NULL) && IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket > 0) {
            if(!m_assetMgr.IsAssetExists(ticket, sig.GetType())) {
                string reason = "";
                int closeStatus = m_assetMgr.CheckHistoryClosure(ticket, reason);

                int finalStatus = XE_CLOSED_MANUAL;
                string statusMsg = "";

                if(closeStatus == XE_CLOSED_SL) {
                    finalStatus = XE_CLOSED_SL;
                    statusMsg = StringFormat("Broker SL Triggered: Physical Asset(%I64u) closed. Reason: %s", ticket, reason);
                } else if(closeStatus == XE_CLOSED_TP) {
                    finalStatus = XE_CLOSED_TP;
                    statusMsg = StringFormat("Broker TP Triggered: Physical Asset(%I64u) closed. Reason: %s", ticket, reason);
                } else if(closeStatus == XE_CLOSED_SIGNAL) {
                    finalStatus = XE_CLOSED_SIGNAL;
                    statusMsg = StringFormat("Signal Closed: Physical Asset(%I64u) closed. Reason: %s", ticket, reason);
                } else {
                    finalStatus = XE_CLOSED_MANUAL;
                    statusMsg = StringFormat("Manual Close Detected: Physical Asset(%I64u) disappeared.", ticket);
                }

                XP_LOG_WARN(xp, CXAuditFormatter::Build("INTENT-WATCH", xp, statusMsg));
                
                sig.SetStatus(finalStatus);
                sig.SetXAExit(XA_CLOSED_COMPLETED);
                sig.SetStatusMsg(statusMsg);
                
                m_repo.ForceUpdateIntent(sig);
                return SESSION_CLOSED;
            }
        }

        ICXSignal* fresh = m_repo.GetSignalBySid(sig.GetSid());
        if(IS_VALID(fresh)) {
            if(fresh.GetXAExit() == XA_ACTIVE && sig.GetXAExit() != XA_ACTIVE) {
                sig.SetXAExit(XA_ACTIVE);
                XP_LOG_INFO(xp, CXAuditFormatter::Build("INTENT-WATCH", xp, "External Exit Intent Synchronized from DB."));
            }
            delete fresh;
        }

        if(sig.GetXAExit() == XA_ACTIVE) return SESSION_LIQUIDATING;
        return TASK_CONTINUE;
    }
};

#endif
