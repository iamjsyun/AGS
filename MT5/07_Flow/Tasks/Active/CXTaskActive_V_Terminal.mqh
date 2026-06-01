#ifndef CX_TASK_ACTIVE_V_TERMINAL_MQH
#define CX_TASK_ACTIVE_V_TERMINAL_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXTaskActive_V_Terminal
 * @brief [Verify] Verify terminal physical state (SL/TP hits, etc.)
 */
class CXTaskActive_V_Terminal : public IXTask {
private:
    ICXAssetManager* m_invMgr;

public:
    virtual string Name() override { return "Active_V_Terminal"; }
    virtual string GetRequiredServices() override { return "asset_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        if(IS_INVALID(m_invMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return TASK_BREAK;

        ulong ticket = (ulong)sig.GetTicket();
        bool exists = m_invMgr.IsPositionExists(ticket);

        xp.SetInt(exists ? 1 : 0); 
        return TASK_CONTINUE;
    }
};

#endif
