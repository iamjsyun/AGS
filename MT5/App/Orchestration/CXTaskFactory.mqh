#ifndef CXTASKFACTORY_MQH
#define CXTASKFACTORY_MQH

#include "..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"

// Entry Tasks
#include "..\..\Session\Workflow\Entry\CXTaskEntry_L_Redirect.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_L_Identity.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_L_Risk.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_L_Price.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_P_Intent.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_L_Validate.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskGuard_V_Spread.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskGuard_V_Volatility.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_P_Lock.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_R_Order.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_V_Error.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_V_TICKET.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_V_REAL.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskFinalize_V_DoubleCheck.mqh"
#include "..\..\Session\Workflow\Entry\CXTaskEntry_P_Finalize.mqh"

// Pending Tasks
#include "..\..\Session\Workflow\Pending\CXTaskPending_V_Sync.mqh"
#include "..\..\Session\Workflow\Pending\CXTaskPending_V_Terminal.mqh"
#include "..\..\Session\Workflow\Pending\CXTaskPending_P_Align.mqh"
#include "..\..\Session\Workflow\Pending\CXTaskPending_R_Apply.mqh"

// Active Tasks
#include "..\..\Session\Workflow\Active\CXTaskIntentWatch.mqh"
#include "..\..\Session\Workflow\Active\CXTaskComm_V_Status.mqh"
#include "..\..\Session\Workflow\Active\CXTaskSync_V_Stale.mqh"
#include "..\..\Session\Workflow\Active\CXTaskActive_V_Terminal.mqh"
#include "..\..\Session\Workflow\Active\CXTaskActive_P_Align.mqh"
#include "..\..\Session\Workflow\Active\CXTaskActive_L_Status.mqh"
#include "..\..\Session\Workflow\Active\CXTaskActive_R_AlphaApply.mqh"
#include "..\..\Session\Workflow\Active\CXTaskActive_P_Closed.mqh"

// Exit Tasks
#include "..\..\Session\Workflow\Exit\CXTaskExit_L_Prepare.mqh"
#include "..\..\Session\Workflow\Exit\CXTaskExit_P_Lock.mqh"
#include "..\..\Session\Workflow\Exit\CXTaskExit_R_Order.mqh"
#include "..\..\Session\Workflow\Exit\CXTaskExit_V_Error.mqh"
#include "..\..\Session\Workflow\Exit\CXTaskExit_V_Terminal.mqh"
#include "..\..\Session\Workflow\Exit\CXTaskExit_P_Finalize.mqh"

// Next-Gen Trailing Tasks
#include "..\..\Session\Workflow\Trailing\CXTaskTrail_V_Activate.mqh"
#include "..\..\Session\Workflow\Trailing\CXTaskTrail_V_Extremum.mqh"
#include "..\..\Session\Workflow\Trailing\CXTaskTrail_L_Evaluate.mqh"
#include "..\..\Session\Workflow\Trailing\CXTaskTrail_R_Execute.mqh"

/**
 * @class CXTaskFactory
 * @brief [v17.6] 문자열 기반 IXTask 객체 생성을 담당 (Hyper-Atomic)
 */
class CXTaskFactory {
public:
    /**
     * @brief [v17.6] 문자열 이름을 기반으로 IXTask 객체 생성
     */
    static IXTask* CreateTask(string name) {
        // Entry
        if(name == "TASK_E_L_REDIRECT")    return new CXTaskEntry_L_Redirect();
        if(name == "TASK_E_L_IDENTITY")    return new CXTaskEntry_L_Identity();
        if(name == "TASK_E_L_RISK")        return new CXTaskEntry_L_Risk();
        if(name == "TASK_E_L_PRICE")       return new CXTaskEntry_L_Price();
        if(name == "TASK_E_P_INTENT")      return new CXTaskEntry_P_Intent();
        if(name == "TASK_E_L_VALIDATE")    return new CXTaskEntry_L_Validate();
        if(name == "TASK_E_G_SPREAD")      return new CXTaskGuard_V_Spread();
        if(name == "TASK_E_G_VOLATILITY")  return new CXTaskGuard_V_Volatility();
        if(name == "TASK_E_P_LOCK")        return new CXTaskEntry_P_Lock();
        if(name == "TASK_E_R_ORDER")       return new CXTaskEntry_R_Order();
        if(name == "TASK_E_V_ERROR")       return new CXTaskEntry_V_Error();
        if(name == "TASK_E_V_TICKET")      return new CXTaskEntry_V_Ticket();
        if(name == "TASK_E_V_REAL")        return new CXTaskEntry_V_Real();
        if(name == "TASK_E_V_DOUBLECHECK") return new CXTaskFinalize_V_DoubleCheck();
        if(name == "TASK_E_P_FINALIZE")    return new CXTaskEntry_P_Finalize();
        
        // Pending & Trailing Entry (Next-Gen)
        if(name == "TASK_P_V_SYNC")        return new CXTaskPending_V_Sync();
        if(name == "TASK_P_V_TERMINAL")    return new CXTaskPending_V_Terminal();
        if(name == "TASK_P_P_ALIGN")       return new CXTaskPending_P_Align();
        if(name == "TASK_P_R_APPLY")       return new CXTaskPending_R_Apply();

        // Next-Gen Trailing Entry (TE)
        if(name == "TASK_T_V_ACTIVATE_TE") return new CXTaskTrail_V_Activate(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_V_EXTREMUM_TE") return new CXTaskTrail_V_Extremum(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_L_EVALUATE_TE") return new CXTaskTrail_L_Evaluate(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_R_EXECUTE_TE")  return new CXTaskTrail_R_Execute(TRAIL_MODE_ENTRY);
        
        // Active & Trailing Stop
        if(name == "TASK_A_INTENT_WATCH")      return new CXTaskIntentWatch();
        if(name == "TASK_A_V_STATUS")          return new CXTaskComm_V_Status();
        if(name == "TASK_A_V_STALE")           return new CXTaskSync_V_Stale();
        if(name == "TASK_A_V_TERMINAL")        return new CXTaskActive_V_Terminal();
        if(name == "TASK_A_P_ALIGN")           return new CXTaskActive_P_Align();
        if(name == "TASK_A_L_Status")          return new CXTaskActive_L_Status();
        if(name == "TASK_ACTIVE_CLOSED")       return new CXTaskActive_P_Closed(); // Specific cleanup

        // Next-Gen Trailing Stop (TS)
        if(name == "TASK_T_V_ACTIVATE_TS") return new CXTaskTrail_V_Activate(TRAIL_MODE_EXIT);
        if(name == "TASK_T_V_EXTREMUM_TS") return new CXTaskTrail_V_Extremum(TRAIL_MODE_EXIT);
        if(name == "TASK_T_L_EVALUATE_TS") return new CXTaskTrail_L_Evaluate(TRAIL_MODE_EXIT);
        if(name == "TASK_T_R_EXECUTE_TS")  return new CXTaskTrail_R_Execute(TRAIL_MODE_EXIT);
        
        // Exit
        if(name == "TASK_X_L_PREPARE")     return new CXTaskExit_L_Prepare();
        if(name == "TASK_X_P_LOCK")        return new CXTaskExit_P_Lock();
        if(name == "TASK_X_R_ORDER")       return new CXTaskExit_R_Order();
        if(name == "TASK_X_V_ERROR")       return new CXTaskExit_V_Error();
        if(name == "TASK_X_V_TERMINAL")    return new CXTaskExit_V_Terminal();
        if(name == "TASK_X_P_FINALIZE")    return new CXTaskExit_P_Finalize();
        
        return NULL;
    }

    /**
     * @brief [v16.6] 호환성 유지를 위한 구형 메서드 스텁
     */
    static bool Exists(string name) {
        IXTask* t = CreateTask(name);
        if(IS_VALID(t)) {
            delete t;
            return true;
        }
        return false;
    }
};

#endif
