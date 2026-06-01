#ifndef CXSEQUENCEFACTORY_MQH
#define CXSEQUENCEFACTORY_MQH

#include "..\Sequence\CXSequenceOrchestrator.mqh"

/**
 * @class CXSequenceFactory
 * @brief [v1.0] Factory for building sequence maps using Domain Specific Language (DSL)
 * @details Encapsulates all sequence definitions to keep AppOrchestrator lean and focused on execution.
 */
class CXSequenceFactory {
public:
    /**
     * @brief Builds the core system bootstrap map
     */
    static void BuildSystemMap(CArrayObj* targetMap, CXSequenceOrchestrator* orch) {
        string dsl[] = {
            "SYS_BOOTSTRAP             > SystemSetup        ? WATCHER_ENTRY_DISCOVERY  ! SYS_ERROR"
        };
        orch.BuildFromDSL(dsl, targetMap);
    }

    /**
     * @brief Builds the 4-step core watcher sequence (Discovery ~ Execute)
     */
    static void BuildWatcherMap(CArrayObj* targetMap, CXSequenceOrchestrator* orch) {
        string dsl[] = {
            "WATCHER_ENTRY_DISCOVERY   > EntryDiscovery     ? WATCHER_ENTRY_EXECUTE    ! WATCHER_EXIT_DISCOVERY    @ 0s, 0x",
            "WATCHER_ENTRY_EXECUTE     > EntryExecute       ? WATCHER_EXIT_DISCOVERY   ! WATCHER_EXIT_DISCOVERY    @ 0s, 0x",

            "WATCHER_EXIT_DISCOVERY    > ExitDiscovery      ? WATCHER_EXIT_EXECUTE     ! WATCHER_ENTRY_DISCOVERY   @ 0s, 0x",
            "WATCHER_EXIT_EXECUTE      > ExitExecute        ? WATCHER_ENTRY_DISCOVERY  ! WATCHER_ENTRY_DISCOVERY   @ 0s, 0x"
        };
        orch.BuildFromDSL(dsl, targetMap);
    }

    /**
     * @brief Builds the asset-level session sequences (Pending, Positioned, Trailing, Exit)
     */
    static void BuildSessionMap(CArrayObj* targetMap, CXSequenceOrchestrator* orch) {
        // A. Pending order management system
        string pendingDsl[] = {
            "ORD_TRACKING                                                                  "
            "> Stage_OrderOptimization                                                     "
            "  : TASK_A_INTENT_WATCH, TASK_T_V_ACTIVATE_TE, TASK_T_V_EXTREMUM_TE,          "
            "    TASK_T_L_EVALUATE_TE, TASK_T_R_EXECUTE_TE, TASK_P_V_SYNC, TASK_A_V_STALE   "
            "? ORD_TRACKING                                                                "
            "! SYS_ERROR                                                                   "
            "@ 300s, 0x                                                                    "
            "* 10=POS_MONITORING, 20=SESSION_LIQUIDATING" 
        };
        orch.BuildFromDSL(pendingDsl, targetMap);

        // B. Position management system
        string positionedDsl[] = {
            "POS_MONITORING                                                                "
            "> Stage_PositionGovernance                                                    "
            "  : TASK_A_INTENT_WATCH, TASK_T_V_ACTIVATE_TS, TASK_A_V_TERMINAL, TASK_A_P_ALIGN"
            "? POS_MONITORING                                                              "
            "! SYS_ERROR                                                                   "
            "@ 3600s, 0x                                                                   "
            "* 15=POS_TRAILING, 20=SESSION_LIQUIDATING" 
        };
        orch.BuildFromDSL(positionedDsl, targetMap);

        // B-2. Position trailing dedicated system (v17.6 Trailing Mode)
        string trailingDsl[] = {
            "POS_TRAILING                                                                  "
            "> Stage_PositionTrailing                                                      "
            "  : TASK_A_INTENT_WATCH, TASK_T_V_EXTREMUM_TS, TASK_T_L_EVALUATE_TS,          "
            "    TASK_T_R_EXECUTE_TS, TASK_A_V_TERMINAL, TASK_A_P_ALIGN                    "
            "? POS_TRAILING                                                                "
            "! SYS_ERROR                                                                   "
            "@ 3600s, 0x                                                                   "
            "* 20=SESSION_LIQUIDATING"
        };
        orch.BuildFromDSL(trailingDsl, targetMap);

        // C. Liquidation management system (Exit/Liquidation)
        string exitDsl[] = {
            "SESSION_LIQUIDATING                                                           "
            "> Stage_PositionLiquidation                                                   "
            "  : TASK_A_INTENT_WATCH, TASK_X_L_PREPARE, TASK_X_P_LOCK, TASK_X_R_ORDER,      "
            "    TASK_X_V_ERROR,      TASK_X_V_TERMINAL, TASK_X_P_FINALIZE                 "
            "? SYS_CLOSED                                                                  "
            "! SYS_ERROR                                                                   "
            "@ 300s, 3x"
        };
        orch.BuildFromDSL(exitDsl, targetMap);
    }
};

#endif
