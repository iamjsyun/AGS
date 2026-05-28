#ifndef CX_TASK_PENDING_V_TERMINAL_MQH
#define CX_TASK_PENDING_V_TERMINAL_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

/**
 * @class CXTaskPending_V_Terminal
 * @brief [Verify] 터미널 내 대기 오더 존재 여부 검증 (v17.6)
 */
class CXTaskPending_V_Terminal : public IXTask {
public:
    virtual string Name() override { return "Pending_V_Terminal"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
        
        if(IS_INVALID(sig) || IS_INVALID(invMgr)) return TASK_BREAK;

        ulong ticket = (ulong)sig.GetTicket();
        if(ticket <= 0) return TASK_BREAK;

        // 터미널에 오더가 존재하는지 확인
        bool exists = invMgr.IsOrderExists(ticket);
        
        if(exists) {
            return TASK_CONTINUE;
        }

        return TASK_YIELD;
    }
};

#endif
