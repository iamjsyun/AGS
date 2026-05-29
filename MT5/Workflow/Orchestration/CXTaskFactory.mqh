#ifndef CXTASKFACTORY_MQH
#define CXTASKFACTORY_MQH

#include "..\..\Core\Interfaces\IXTask.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"

// Pending Tasks
#include "..\Tasks\Pending\CXTaskPending_V_Sync.mqh"

// Active Tasks
#include "..\Tasks\Active\CXTaskIntentWatch.mqh"
#include "..\Tasks\Active\CXTaskSync_V_Stale.mqh"
#include "..\Tasks\Active\CXTaskActive_V_Terminal.mqh"
#include "..\Tasks\Active\CXTaskActive_P_Align.mqh"

// Exit Tasks
#include "..\Tasks\Exit\CXTaskExit_L_Prepare.mqh"
#include "..\Tasks\Exit\CXTaskExit_P_Lock.mqh"
#include "..\Tasks\Exit\CXTaskExit_R_Order.mqh"
#include "..\Tasks\Exit\CXTaskExit_V_Error.mqh"
#include "..\Tasks\Exit\CXTaskExit_V_Terminal.mqh"
#include "..\Tasks\Exit\CXTaskExit_P_Finalize.mqh"

// Next-Gen Trailing Tasks
#include "..\Tasks\Trailing\CXTaskTrail_V_Activate.mqh"
#include "..\Tasks\Trailing\CXTaskTrail_V_Extremum.mqh"
#include "..\Tasks\Trailing\CXTaskTrail_L_Evaluate.mqh"
#include "..\Tasks\Trailing\CXTaskTrail_R_Execute.mqh"

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
        // Pending & Trailing Entry (Next-Gen)
        if(name == "TASK_P_V_SYNC")        return new CXTaskPending_V_Sync();

        // Next-Gen Trailing Entry (TE)
        if(name == "TASK_T_V_ACTIVATE_TE") return new CXTaskTrail_V_Activate(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_V_EXTREMUM_TE") return new CXTaskTrail_V_Extremum(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_L_EVALUATE_TE") return new CXTaskTrail_L_Evaluate(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_R_EXECUTE_TE")  return new CXTaskTrail_R_Execute(TRAIL_MODE_ENTRY);
        
        // Active & Trailing Stop
        if(name == "TASK_A_INTENT_WATCH")      return new CXTaskIntentWatch();
        if(name == "TASK_A_V_STALE")           return new CXTaskSync_V_Stale();
        if(name == "TASK_A_V_TERMINAL")        return new CXTaskActive_V_Terminal();
        if(name == "TASK_A_P_ALIGN")           return new CXTaskActive_P_Align();

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
