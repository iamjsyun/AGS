#ifndef CX_TASK_TRAIL_R_EXECUTE_MQH
#define CX_TASK_TRAIL_R_EXECUTE_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Models\CXParam.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXOrderManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXExitManager.mqh"
#include "..\..\..\Platform\Engine\Trailing\CXTrailingEngine.mqh"

/**
 * @class CXTaskTrail_R_Execute
 * @brief [Request] 트레일링 트리거 발생 시 실제 거래 실행 (진입/청산)
 */
class CXTaskTrail_R_Execute : public IXTask {
private:
    ENUM_TRAIL_MODE m_mode;

public:
    CXTaskTrail_R_Execute(ENUM_TRAIL_MODE mode) : m_mode(mode) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_R_Execute_TE" : "Trail_R_Execute_TS"; }
    
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        int code = xp.GetInt();
        if(IS_INVALID(sig) || code <= 0) return TASK_CONTINUE;

        if(m_mode == TRAIL_MODE_ENTRY && code == 10) {
            // [진트 실행] 대기 주문 취소 후 시장가 진입
            IXOrderManager* orderMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
            if(IS_INVALID(orderMgr)) return SESSION_ERROR;

            sig.SetStatusMsg("TE Rebound: Executing Market Entry...");
            
            // [v1.3.1 Fix] 보안 가드 우회를 위한 티켓/상태 초기화
            ulong oldTicket = (ulong)sig.GetTicket();
            orderMgr.DeleteOrder(xp, oldTicket);
            
            sig.SetTicket(0);
            sig.SetStatus(XE_READY);
            sig.SetType(ORDER_MARKET);
            
            if(orderMgr.ExecuteEntry(xp)) {
                sig.SetTag("ENTRY_TE_REBOUND");
                XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, "TE Market Fallback Success."));
                // 전이 코드 10 유지 (Orchestrator: POS_MONITORING 전이)
                return TASK_CONTINUE;
            }
        } else if(m_mode == TRAIL_MODE_EXIT && code == 20) {
            // [익트 실행] 
            // 참고: Orchestrator가 20번 코드를 받아 SESSION_LIQUIDATING 단계로 자동 전이하므로 
            // 여기서는 추가 로깅만 수행하거나 생략 가능합니다.
            XP_LOG_INFO(xp, CXAuditFormatter::Build(Name(), xp, "TS Retraction Triggered. Transitioning to Liquidation..."));
            return TASK_CONTINUE;
        }

        return TASK_CONTINUE;
    }
};

#endif
