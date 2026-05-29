#ifndef CXSIGNALSCHEMA_MQH
#define CXSIGNALSCHEMA_MQH

/**
 * @section Schema SSOT Definition
 * @brief 모든 필드 정보를 통합 관리.
 * @param type 데이터 타입
 * @param name MQL5 변수명 & DB 컬럼명
 * @param dbType SQLite 바인딩 타입
 * @param getter Get{getter} 형태의 Getter 명칭
 */
#define SIGNAL_SCHEMA_FIELDS \
    X(int,      id,           Integer, Id)          \
    X(string,   sid,          Text,    Sid)         \
    X(int,      cno,          Integer, Cno)         \
    X(int,      sno,          Integer, Sno)         \
    X(int,      msg_id,       Integer, MsgId)       \
    X(int,      raw_id,       Integer, RawId)       \
    X(int,      xa_entry,     Integer, XAEntry)     \
    X(int,      xa_exit,      Integer, XAExit)      \
    X(int,      xe_status,    Integer, Status)      \
    X(string,   xe_status_msg,Text,    StatusMsg)   \
    X(string,   time,         Text,    Time)        \
    X(string,   symbol,       Text,    Symbol)      \
    X(int,      dir,          Integer, Dir)         \
    X(int,      type,         Integer, Type)        \
    X(double,   price_signal, Double,  PriceSignal) \
    X(double,   te_start,     Double,  TEStart)     \
    X(double,   te_step,      Double,  TEStep)      \
    X(double,   te_limit,     Double,  TELimit)     \
    X(int,      te_interval,  Integer, TEInterval)  \
    X(double,   ikte_start,   Double,  IkTeStart)   \
    X(double,   ikte_step,    Double,  IkTeStep)    \
    X(double,   tp,           Double,  TP)          \
    X(double,   sl,           Double,  SL)          \
    X(int,      close_type,   Integer, CloseType)   \
    X(double,   price,        Double,  Price)       \
    X(double,   price_open,   Double,  PriceOpen)   \
    X(double,   price_close,  Double,  PriceClose)  \
    X(double,   price_tp,     Double,  PriceTP)     \
    X(double,   price_sl,     Double,  PriceSL)     \
    X(double,   lot,          Double,  Lot)         \
    X(ulong,    ticket,       Long,    Ticket)      \
    X(long,     magic,        Long,    Magic)       \
    X(string,   comment,      Text,    Comment)     \
    X(string,   tag,          Text,    Tag)         \
    X(datetime, created,      Text,    Created)     \
    X(datetime, updated,      Text,    Updated)

#endif
