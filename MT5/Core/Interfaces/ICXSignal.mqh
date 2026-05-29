#ifndef ICXSIGNAL_MQH
#define ICXSIGNAL_MQH

#include <Object.mqh>
#include "CXSignalSchema.mqh"

/**
 * @class ICXSignal
 * @brief 신호 엔티티에 대한 추상 인터페이스 (Schema Auto-generation)
 */
class ICXSignal : public CObject {
public:
    virtual ~ICXSignal() {}

    //--- [SSOT] 필드 접근자 자동 생성 (Getter/Setter)
    #define X(type, name, dbType, getter) \
        virtual type Get##getter() const = 0; \
        virtual void Set##getter(type v) = 0;
    
    SIGNAL_SCHEMA_FIELDS
    #undef X

    //--- 특수 기능 인터페이스
    virtual int       GetGno() const = 0;
    virtual void      UpdatePriceSignal(double price) = 0;
    virtual double    GetOffset() const = 0;
    
    //--- [v11.0] Log Spam Prevention
    virtual int       GetLastStatus() const = 0;
    virtual void      SetLastStatus(int status) = 0;

    //--- [v1.0] Runtime TS variables (removed from SQLite schema but retained for calculation)
    virtual int       GetTSStart() const = 0;
    virtual void      SetTSStart(int v) = 0;
    virtual int       GetTSStep() const = 0;
    virtual void      SetTSStep(int v) = 0;
};

//--- MQL5 전용 매크로 지원 (컴파일 타임 호환성용)
#define ICX_SIG_ID(s) s.GetId()
#define ICX_SIG_SID(s) s.GetSid()
#define ICX_SIG_STATUS(s) s.GetStatus()

#endif
