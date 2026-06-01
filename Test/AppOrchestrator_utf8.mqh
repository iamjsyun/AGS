#ifndef APPORCHESTRATOR_MQH
#define APPORCHESTRATOR_MQH

#include "..\Sequence\CXSequenceOrchestrator.mqh"

/**
 * @class AppOrchestrator
 * @brief [v18.30] ?먯궛 以묒떖 ?꾪궎?띿쿂??理쒖쟻?붾맂 ?듭떖 ?몃젅?대뵫 ?쒗???뺤쓽
 */
class AppOrchestrator : public CXSequenceOrchestrator {
public:
    AppOrchestrator() : CXSequenceOrchestrator() {
        Initialize();
    }

    /**
     * @brief [v19.30] 珥덇린???쒗??(SystemMap 異붽?)
     */
    virtual void Initialize() override {
        RegisterStandardNames();
        InitSystemMap();
        InitWatcherMap();
        InitSessionMap();
    }

    /**
     * @brief [v19.32] ?쒖뒪??怨듯넻 ?쒗???깅줉 (Bootstrap) - m_system_map???깅줉?섏뿬 Watcher? ?쒖옉??遺꾨━
     */
    void InitSystemMap() {
        string systemDsl[] = {
            "SYS_BOOTSTRAP             > SystemSetup        ? WATCHER_ENTRY_DISCOVERY  ! SYS_ERROR"
        };
        BuildFromDSL(systemDsl, m_system_map);  // [v19.32] m_watcher_map 遺꾨━ -> Watcher??ENTRY_DISCOVERY?먯꽌留??쒖옉
    }

protected:
    virtual void RegisterStandardNames() override {
        // Core Logic States
        m_registry.Add("ORD_TRACKING",          (int)ORD_TRAILING);
        m_registry.Add("POS_MONITORING",        (int)POS_ACTIVE);
        m_registry.Add("SESSION_LIQUIDATING",   (int)SESSION_LIQUIDATING);
        m_registry.Add("SYS_CLOSED",            (int)SYS_CLOSED);
        m_registry.Add("SYS_ERROR",             (int)SYS_ERROR);

        // Watcher States
        m_registry.Add("SYS_BOOTSTRAP",           999);
        m_registry.Add("WATCHER_ENTRY_DISCOVERY", 1000);
        m_registry.Add("WATCHER_ENTRY_EXECUTE",   1001);
        m_registry.Add("WATCHER_EXIT_DISCOVERY",  1002);
        m_registry.Add("WATCHER_EXIT_EXECUTE",    1003);
    }

    /**
     * @brief [v18.30] ?⑥닚 紐낇솗??4?④퀎 肄붿뼱 ?뚯쿂 ?쒗??(Discovery ~ Execute)
     */
    virtual void InitWatcherMap() override {
        string unifiedDsl[] = {
            "WATCHER_ENTRY_DISCOVERY   > EntryDiscovery     ? WATCHER_ENTRY_EXECUTE    ! WATCHER_EXIT_DISCOVERY    @ 0s, 0x",
            "WATCHER_ENTRY_EXECUTE     > EntryExecute       ? WATCHER_EXIT_DISCOVERY   ! WATCHER_EXIT_DISCOVERY    @ 0s, 0x",

            "WATCHER_EXIT_DISCOVERY    > ExitDiscovery      ? WATCHER_EXIT_EXECUTE     ! WATCHER_ENTRY_DISCOVERY   @ 0s, 0x",
            "WATCHER_EXIT_EXECUTE      > ExitExecute        ? WATCHER_ENTRY_DISCOVERY  ! WATCHER_ENTRY_DISCOVERY   @ 0s, 0x"
        };
        BuildFromDSL(unifiedDsl, m_watcher_map);
    }

    /**
     * @brief [v18.30] ?먯궛 ?⑥쐞 ?쒖뒪???쒗??(Unit Task DSL)
     */
    virtual void InitSessionMap() override {
        // A. ?湲?二쇰Ц 愿由??쒖뒪??(Pending)
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
        BuildFromDSL(pendingDsl, m_session_map);

        // B. ?ъ???愿由??쒖뒪??(Positioned)
        string positionedDsl[] = {
            "POS_MONITORING                                                                "
            "> Stage_PositionGovernance                                                    "
            "  : TASK_A_INTENT_WATCH, TASK_T_V_ACTIVATE_TS, TASK_A_V_TERMINAL, TASK_A_P_ALIGN"
            "? POS_MONITORING                                                              "
            "! SYS_ERROR                                                                   "
            "@ 3600s, 0x                                                                   "
            "* 15=POS_TRAILING, 20=SESSION_LIQUIDATING" 
        };
        BuildFromDSL(positionedDsl, m_session_map);

        // B-2. ?ъ????몃젅?쇰쭅 ?꾩슜 ?쒖뒪??(v17.6 Trailing Mode)
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
        BuildFromDSL(trailingDsl, m_session_map);

        // C. 泥?궛 愿由??쒖뒪??(Exit/Liquidation)
        string exitDsl[] = {
            "SESSION_LIQUIDATING                                                           "
            "> Stage_PositionLiquidation                                                   "
            "  : TASK_A_INTENT_WATCH, TASK_X_L_PREPARE, TASK_X_P_LOCK, TASK_X_R_ORDER,      "
            "    TASK_X_V_ERROR,      TASK_X_V_TERMINAL, TASK_X_P_FINALIZE                 "
            "? SYS_CLOSED                                                                  "
            "! SYS_ERROR                                                                   "
            "@ 300s, 3x"
        };
        BuildFromDSL(exitDsl, m_session_map);
    }
};

#endif
