#ifndef CXTASKFACTORY_MQH
#define CXTASKFACTORY_MQH

#include "..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include <Arrays\ArrayString.mqh>

// Pending Tasks
#include "..\..\07_Flow\Tasks\Pending\CXTaskPending_V_Sync.mqh"

// Active Tasks
#include "..\..\07_Flow\Tasks\Active\CXTaskIntentWatch.mqh"
#include "..\..\07_Flow\Tasks\Active\CXTaskSync_V_Stale.mqh"
#include "..\..\07_Flow\Tasks\Active\CXTaskActive_V_Terminal.mqh"
#include "..\..\07_Flow\Tasks\Active\CXTaskActive_P_Align.mqh"

// Exit Tasks
#include "..\..\07_Flow\Tasks\Exit\CXTaskExit_L_Prepare.mqh"
#include "..\..\07_Flow\Tasks\Exit\CXTaskExit_P_Lock.mqh"
#include "..\..\07_Flow\Tasks\Exit\CXTaskExit_R_Order.mqh"
#include "..\..\07_Flow\Tasks\Exit\CXTaskExit_V_Error.mqh"
#include "..\..\07_Flow\Tasks\Exit\CXTaskExit_V_Terminal.mqh"
#include "..\..\07_Flow\Tasks\Exit\CXTaskExit_P_Finalize.mqh"

// Next-Gen Trailing Tasks
#include "..\..\07_Flow\Tasks\Trailing\CXTaskTrail_V_Activate.mqh"
#include "..\..\07_Flow\Tasks\Trailing\CXTaskTrail_V_Extremum.mqh"
#include "..\..\07_Flow\Tasks\Trailing\CXTaskTrail_L_Evaluate.mqh"
#include "..\..\07_Flow\Tasks\Trailing\CXTaskTrail_R_Execute.mqh"

/**
 * @class CXTaskFactory
 * @brief [v2.2] String-based IXTask object creation and list return (Smart PVB Support)
 */
class CXTaskFactory {
public:
    /**
     * @brief [v2.2] Returns a list of all task names available in the engine
     */
    static void GetAvailableTasks(CArrayString &list) {
        list.Clear();
        list.Add("TASK_P_V_SYNC");
        list.Add("TASK_T_V_ACTIVATE_TE");
        list.Add("TASK_T_V_EXTREMUM_TE");
        list.Add("TASK_T_L_EVALUATE_TE");
        list.Add("TASK_T_R_EXECUTE_TE");
        list.Add("TASK_A_INTENT_WATCH");
        list.Add("TASK_A_V_STALE");
        list.Add("TASK_A_V_TERMINAL");
        list.Add("TASK_A_P_ALIGN");
        list.Add("TASK_T_V_ACTIVATE_TS");
        list.Add("TASK_T_V_EXTREMUM_TS");
        list.Add("TASK_T_L_EVALUATE_TS");
        list.Add("TASK_T_R_EXECUTE_TS");
        list.Add("TASK_X_L_PREPARE");
        list.Add("TASK_X_P_LOCK");
        list.Add("TASK_X_R_ORDER");
        list.Add("TASK_X_V_ERROR");
        list.Add("TASK_X_V_TERMINAL");
        list.Add("TASK_X_P_FINALIZE");
    }

    static IXTask* CreateTask(string name) {
        if(name == "TASK_P_V_SYNC")        return new CXTaskPending_V_Sync();
        if(name == "TASK_T_V_ACTIVATE_TE") return new CXTaskTrail_V_Activate(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_V_EXTREMUM_TE") return new CXTaskTrail_V_Extremum(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_L_EVALUATE_TE") return new CXTaskTrail_L_Evaluate(TRAIL_MODE_ENTRY);
        if(name == "TASK_T_R_EXECUTE_TE")  return new CXTaskTrail_R_Execute(TRAIL_MODE_ENTRY);
        if(name == "TASK_A_INTENT_WATCH")      return new CXTaskIntentWatch();
        if(name == "TASK_A_V_STALE")           return new CXTaskSync_V_Stale();
        if(name == "TASK_A_V_TERMINAL")        return new CXTaskActive_V_Terminal();
        if(name == "TASK_A_P_ALIGN")           return new CXTaskActive_P_Align();
        if(name == "TASK_T_V_ACTIVATE_TS") return new CXTaskTrail_V_Activate(TRAIL_MODE_EXIT);
        if(name == "TASK_T_V_EXTREMUM_TS") return new CXTaskTrail_V_Extremum(TRAIL_MODE_EXIT);
        if(name == "TASK_T_L_EVALUATE_TS") return new CXTaskTrail_L_Evaluate(TRAIL_MODE_EXIT);
        if(name == "TASK_T_R_EXECUTE_TS")  return new CXTaskTrail_R_Execute(TRAIL_MODE_EXIT);
        if(name == "TASK_X_L_PREPARE")     return new CXTaskExit_L_Prepare();
        if(name == "TASK_X_P_LOCK")        return new CXTaskExit_P_Lock();
        if(name == "TASK_X_R_ORDER")       return new CXTaskExit_R_Order();
        if(name == "TASK_X_V_ERROR")       return new CXTaskExit_V_Error();
        if(name == "TASK_X_V_TERMINAL")    return new CXTaskExit_V_Terminal();
        if(name == "TASK_X_P_FINALIZE")    return new CXTaskExit_P_Finalize();
        return NULL;
    }

    static bool Exists(string name) {
        IXTask* t = CreateTask(name);
        if(IS_VALID(t)) { delete t; return true; }
        return false;
    }
};

#endif
