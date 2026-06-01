#ifndef CX_TASK_EXIT_R_ORDER_MQH
#define CX_TASK_EXIT_R_ORDER_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Interfaces\IXExitManager.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\01_Core\Interfaces\ICXAssetManager.mqh"

/**
 * @class CXTaskExit_R_Order
 * @brief [Request] Send liquidation (Close/Cancel) order to broker
 * [v2.1 Smart PVB] Implementation of GetRequiredServices
 */
class CXTaskExit_R_Order : public IXTask {
private:
    IXExitManager*   m_exitMgr;
    ICXAssetManager* m_assetMgr;

public:
    CXTaskExit_R_Order() {
        SetTimeout(30); 
    }

    virtual string Name() override { return "Exit_R_Order"; }
    
    virtual string GetRequiredServices() override { return "exit_mgr, asset_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_exitMgr  = CX_GET_OBJ(ctx, "exit_mgr", IXExitManager);
        m_assetMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(m_exitMgr) || IS_INVALID(m_assetMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        if(xp.GetInt() == 3) return TASK_CONTINUE;

        m_assetMgr.SyncToSignal(sig);

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket > 0 && !m_assetMgr.IsAssetExists(ticket, sig.GetType())) {
            XP_LOG_WARN(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, StringFormat("Physical Asset(%I64u) already gone. Skipping.", ticket)));
            return TASK_CONTINUE; 
        }
        
        if(m_exitMgr.SweepBySid(xp, sig.GetSid())) {
            XP_LOG_OK(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, "SUCCESS: Massive SID Sweep executed."));
            xp.SetInt(3);
            return TASK_CONTINUE;
        }

        XP_LOG_WARN(xp, CXAuditFormatter::Build("EXIT-R-ORDER", xp, "RETRY: Broker Request Rejected. Retrying via TASK_YIELD..."));
        return TASK_YIELD; 
    }
};

#endif
