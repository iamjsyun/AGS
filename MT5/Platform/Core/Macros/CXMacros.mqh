#ifndef CX_MACROS_MQH
#define CX_MACROS_MQH

#include "..\Defines\CXMessageDictionary.mqh"
#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXContext.mqh"
#include "..\Interfaces\ICXLogger.mqh"
#include "..\Interfaces\ICXConfig.mqh"

/**
 * @file CXMacros.mqh
 * @brief XTA 시스템 전역 매크로 정의 (Functional Macros)
 * @details 객체 유효성 체크, 로깅, 타입 캐스팅 등 기능성 매크로 모음
 */

//--- 포인터 안전 삭제 매크로
#ifndef SAFE_DELETE
#define SAFE_DELETE(p) { if(CheckPointer(p) == POINTER_DYNAMIC) { delete p; p = NULL; } }
#endif

#ifndef SAFE_DELETE_ARRAY
#define SAFE_DELETE_ARRAY(p) { if(CheckPointer(p) == POINTER_DYNAMIC) { delete [] p; p = NULL; } }
#endif

//--- 포인터 및 객체 유효성 체크 매크로
#define IS_INVALID(p)   (CheckPointer(p) == POINTER_INVALID)
#define IS_VALID(p)     (CheckPointer(p) != POINTER_INVALID)
#define IS_NULL(p)      (IS_INVALID(p))

//--- 타입 안전성 강화를 위한 명시적 캐스팅 매크로
#define CX_CAST(type, obj)      (type*)(obj)
#define CX_SAFE_CAST(type, obj) (IS_VALID(obj) ? (type*)(obj) : NULL)

//--- 가드 클로저 (Guard Clauses)
#define XP_ASSERT(xp)           if(CheckPointer(xp) == POINTER_INVALID) return
#define XP_ASSERT_FALSE(xp)     if(CheckPointer(xp) == POINTER_INVALID) return false
#define XP_ASSERT_NULL(xp)      if(CheckPointer(xp) == POINTER_INVALID) return NULL

//--- 서비스 및 객체 획득 매크로 (Surgical Resolve)
#define CX_GET_OBJ(ctx, key, type) (IS_VALID(ctx) ? (type*)(ctx.Get(key)) : NULL)

//--- 로깅 헬퍼 함수
inline ICXLogger* GetLoggerSafe(ICXParam* xp, ENUM_LOG_LEVEL level, bool is_sequence) {
    if(CheckPointer(xp) == POINTER_INVALID) return NULL;
    ICXContext* ctx = xp.GetContext();
    if(CheckPointer(ctx) == POINTER_INVALID) return NULL;
    
    ICXConfig* config = ctx.GetConfig();
    if(CheckPointer(config) == POINTER_INVALID) return NULL;

    // 0. Log Level 필터링 (선택된 레벨 이상만 출력)
    if(level < config.GetLogLevel()) return NULL;

    // 1. System Log 체크 (is_sequence가 아닐 때)
    if(!is_sequence && !config.IsSystemLogEnabled()) return NULL;

    // 2. Sequence Log 체크 (CNO 필터링)
    if(is_sequence) {
        ICXSignal* sig = xp.GetSignal();
        long cno = (IS_VALID(sig)) ? sig.GetCno() : 0;
        if(!config.IsSequenceLogEnabled(cno)) return NULL;
    }

    return ctx.GetLogger();
}

//--- 로깅 매크로 (CXParam/Context 기반) - On-Change Deduplication Enabled
#define XP_LOG_TRACE(xp, msg) { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_TRACE, false); if(IS_VALID(_log)) _log.Trace(xp, msg, LOG_POLICY_ON_CHANGE); }
#define XP_LOG_INFO(xp, msg)  { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_INFO,  false); if(IS_VALID(_log)) _log.Info(xp, msg, LOG_POLICY_ON_CHANGE);  }
#define XP_LOG_DEBUG(xp, msg) { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_DEBUG, false); if(IS_VALID(_log)) _log.Debug(xp, msg, LOG_POLICY_ON_CHANGE); }
#define XP_LOG_WARN(xp, msg)  { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_WARN,  false); if(IS_VALID(_log)) { string _t = StringFormat("[%s:%d in %s] ", __FILE__, __LINE__, __FUNCTION__); _log.Warn(xp, _t + msg, LOG_POLICY_ON_CHANGE); } }
#define XP_LOG_ERROR(xp, msg) { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_ERROR, false); if(IS_VALID(_log)) { string _t = StringFormat("[%s:%d in %s] ", __FILE__, __LINE__, __FUNCTION__); _log.Error(xp, _t + msg, LOG_POLICY_ALWAYS); } }
#define XP_LOG_OK(xp, msg)    { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_OK,    false); if(IS_VALID(_log)) _log.Ok(xp, msg, LOG_POLICY_ALWAYS);    }

//--- 시퀀스 전용 로깅 매크로 (필터링 적용)
#define XP_LOG_SEQ_TRACE(xp, msg) { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_TRACE, true); if(IS_VALID(_log)) _log.Trace(xp, msg, LOG_POLICY_ON_CHANGE); }
#define XP_LOG_SEQ_INFO(xp, msg)  { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_INFO,  true); if(IS_VALID(_log)) _log.Info(xp, msg, LOG_POLICY_ON_CHANGE); }
#define XP_LOG_SEQ_DEBUG(xp, msg) { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_DEBUG, true); if(IS_VALID(_log)) _log.Debug(xp, msg, LOG_POLICY_ON_CHANGE); }
#define XP_LOG_SEQ_WARN(xp, msg)  { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_WARN,  true); if(IS_VALID(_log)) { string _t = StringFormat("[%s:%d in %s] ", __FILE__, __LINE__, __FUNCTION__); _log.Warn(xp, _t + msg, LOG_POLICY_ON_CHANGE); } }
#define XP_LOG_SEQ_ERROR(xp, msg) { ICXLogger* _log = GetLoggerSafe(xp, LOG_LVL_ERROR, true); if(IS_VALID(_log)) { string _t = StringFormat("[%s:%d in %s] ", __FILE__, __LINE__, __FUNCTION__); _log.Error(xp, _t + msg, LOG_POLICY_ALWAYS); } }

#endif
