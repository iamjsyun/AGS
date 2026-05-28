#ifndef CX_DEFINE_MQH
#define CX_DEFINE_MQH

/**
 * @file CXDefine.mqh
 * @brief XTA 시스템 전역 상수 및 열거형 정의 (Constants & Enums)
 * @details 상태 코드, 타입 정의, 고정값 등 정적 데이터 정의 모음
 */

//--- 시스템 규격 상수
#define SID_MAX_LENGTH       23
#define GID_MAX_LENGTH       20
#define COMMENT_MAX_LENGTH   31
#define DEFAULT_SLIPPAGE     30
#define MAX_SLIPPAGE         1000

//--- 로그 레벨 정의
enum ENUM_LOG_LEVEL {
    LOG_LVL_TRACE = 0,
    LOG_LVL_INFO  = 1,
    LOG_LVL_DEBUG = 2,
    LOG_LVL_WARN  = 3,
    LOG_LVL_ERROR = 4,
    LOG_LVL_OK    = 5
};

//--- 방향 정의 (dir)
enum ENUM_CX_DIRECTION {
    CX_DIR_NONE = 0,
    CX_DIR_BUY  = 1,
    CX_DIR_SELL = 2
};

//--- 주문 타입 정의
enum ENUM_CX_ORDER_TYPE {
    ORDER_LIMIT_TRAILING = 1,
    ORDER_LIMIT          = 2,
    ORDER_STOP           = 3,
    ORDER_MARKET         = 9
};

//--- XA_INTENT (UI/외부 명령 의도)
enum ENUM_XA_INTENT {
    XA_RAW           = 0,  // 초기 상태
    XA_ACTIVE        = 1,  // 활성화 (진입/청산 실행)
    XA_CLOSED_COMPLETED = 2,  // [v9.8.11] 청산 완료 (Handshake Acceleration)
    XA_ARCHIVE_READY = 3   // 이관 대기 (App 마킹)
};

//--- XE_STATUS (EA 실행 상태)
enum ENUM_XE_STATUS {
    XE_UNKNOWN          = -1,
    XE_READY            = 0,
    XE_PENDING_REQ      = 1,  // [v11.3] 브로커 요청 전 DB 잠금 상태
    XE_IN_TRANSIT       = 2,  // [v11.3] 명령 송신 완료, 실물 동기화 대기 중
    XE_PENDING_PLACED   = 5,  // [v11.3] 대기 주문 터미널 등록 완료
    XE_EXECUTED         = 10,
    XE_QUARANTINED      = 15, // [v16.4 Scenario C] Zombie Asset Quarantine (User Approval Required)
    XE_CLOSED_SIGNAL    = 20,
    XE_CLOSED_SL        = 21, // [v11.3] 손절 청산
    XE_CLOSED_TP        = 22, // [v11.3] 익절 청산
    XE_CLOSED_MANUAL    = 24,
    XE_VERIFY_ABS       = 25,
    XE_ERROR            = 99
};

//--- 세션 상태 및 시퀀스 단계 정의 (Sequence States)
enum ENUM_SESSION_STATE {
    SESSION_READY            = 0,  ORD_READY            = 0,
    SESSION_VALIDATING       = 1,  ORD_VALIDATING       = 1,  // [v17.6] 리스크 및 데이터 검증
    SESSION_EXECUTING        = 2,  ORD_EXECUTING        = 2,  // [v17.6] 브로커 오더 송신 실행
    SESSION_PENDING          = 3,  ORD_PENDING          = 3,  // [v17.6] 터미널 오더 안착 대기
    SESSION_TRAILING_ENTRY   = 5,  ORD_TRAILING         = 5,  // [v17.6] 진입 가격 추격 (Active TE)
    SESSION_ACTIVE           = 10, POS_ACTIVE           = 10, // 포지션 진입 완료 및 감시
    SESSION_TRAILING_STOP    = 15, POS_TRAILING         = 15, // [v17.6] 수익 보존 추격 (Active TS/Alpha)
    SESSION_LIQUIDATING      = 20, POS_LIQUIDATING      = 20, // 청산 실행
    SESSION_CLOSED           = 30, SYS_CLOSED           = 30, // 세션 종료
    SESSION_ERROR            = 99, SYS_ERROR            = 99  // 에러 상태
};

//--- Watcher 상태 및 시퀀스 단계 정의 (Watcher Sequence States)
enum ENUM_WATCHER_STATE {
    WATCHER_DISCOVERY      = 0,
    WATCHER_VALIDATION     = 1,
    WATCHER_SPAWNING       = 2,
    WATCHER_ERROR          = 99
};

//--- 시스템 이벤트 타입 정의
enum ENUM_CX_EVENT {
    EVENT_TICK          = 0,
    EVENT_TRANSACTION   = 1,
    EVENT_TIMER         = 2,
    EVENT_START         = 100,
    EVENT_INJECT        = 101
};

//--- Stage 실행 공통 결과 (Generic Stage Results)
#define STATE_UNCHANGED     -1
#define STAGE_SUCCESS       -100

//--- 계산 스텝 결과 (Alpha Calculation Results)
enum ENUM_CALC_RESULT {
    CALC_NO_CHANGE = 0,
    CALC_MODIFIED  = 1
};

//--- 시퀀스 내 고정 상태 주소 (ST_ 접두사로 통일)
enum ENUM_STATE_ID {
    // Watcher States
    ST_W_DISCOVERY  = WATCHER_DISCOVERY,
    ST_W_VALIDATION = WATCHER_VALIDATION,
    ST_W_SPAWNING   = WATCHER_SPAWNING,
    
    // Session States
    ST_S_READY              = SESSION_READY,
    ST_S_VALIDATING         = SESSION_VALIDATING,
    ST_S_EXECUTING          = SESSION_EXECUTING,
    ST_S_PENDING            = SESSION_PENDING,
    ST_S_TRAILING_ENTRY     = SESSION_TRAILING_ENTRY,
    ST_S_ACTIVE             = SESSION_ACTIVE,
    ST_S_TRAILING_STOP      = SESSION_TRAILING_STOP,
    ST_S_LIQUIDATING        = SESSION_LIQUIDATING,
    ST_S_CLOSED             = SESSION_CLOSED,
    ST_S_ERROR              = SESSION_ERROR
};

//--- 타임아웃 표준 정의
enum ENUM_TIMEOUT_VAL {
    T_NONE       = 0,
    T_SHORT      = 30,
    T_NORMAL     = 3600,
    T_LONG       = 72000,
    T_ENTRY_EXIT = 300,
    T_VERIFY     = 60
};

//--- [v11.4] 시퀀스 무결성 및 DSL 상수
#define SEQ_NODE_DELIMITER   "|"
#define SEQ_STAGE_DELIMITER  ":"
#define MAX_RETRY_COUNT      5
#define RETRY_BACKOFF_BASE   1000  // MS

#endif
