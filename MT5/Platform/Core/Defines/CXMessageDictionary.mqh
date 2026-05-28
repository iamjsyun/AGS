#ifndef CX_MESSAGE_DICTIONARY_MQH
#define CX_MESSAGE_DICTIONARY_MQH

/**
 * @file CXMessageDictionary.mqh
 * @brief XTA 시스템 전역 상태 메시지 및 에러 코드 정의 (SSOT)
 * @details WPF(ATSA)와의 연동을 위해 [CODE] 형식을 준수함.
 */

//--- [SYS-1xx] 진입 및 주문 관련 (Entry & Order)
#define MSG_ENTRY_MARKET_SUCCESS    "[SYS-101] Market entry executed successfully."
#define MSG_ENTRY_LIMIT_PLACED      "[SYS-102] Limit order placed successfully."
#define MSG_ENTRY_TRAILING_MODIFIED "[SYS-103] Entry price modified by trailing."
#define MSG_ENTRY_EXECUTED          "[SYS-110] Order fully executed."

//--- [SYS-2xx] 청산 및 소멸 관련 (Exit & Liquidation)
#define MSG_EXIT_REQUESTED          "[SYS-201] Liquidation requested by user."
#define MSG_EXIT_TICKET_CLOSED      "[SYS-202] Layer-1: Ticket closed."
#define MSG_EXIT_SWEEP_DONE         "[SYS-203] Layer-2: SID sweep completed."
#define MSG_EXIT_VERIFIED_CLEAN     "[SYS-200] Layer-3: Asset absence verified clean."
#define MSG_EXIT_TS_MODIFIED        "[SYS-210] StopLoss modified by Trailing-Stop."

//--- [SYS-3xx] 세션 상태 관련 (Session Lifecycle)
#define MSG_SESSION_START           "[SYS-301] Trading session started."
#define MSG_SESSION_INJECTED        "[SYS-302] Trading session recovered/injected."
#define MSG_SESSION_CLOSED          "[SYS-300] Trading session closed."

//--- [ERR-xxx] 시스템 에러 관련 (System Errors)
#define MSG_ERR_INTERNAL            "[ERR-000] Critical internal system error."
#define MSG_ERR_MAGIC_INVALID       "[ERR-001] Invalid or unregistered Magic Number."
#define MSG_ERR_SYMBOL_INVALID      "[ERR-002] Unsupported or invalid symbol."
#define MSG_ERR_TRADE_FAILED        "[ERR-010] Trade execution failed by broker."
#define MSG_ERR_DB_SYNC_FAILED      "[ERR-020] Database synchronization failed."
#define MSG_ERR_GUARD_DENIED        "[ERR-030] Validation denied by CXGuard."

#endif
