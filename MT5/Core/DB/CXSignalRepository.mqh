//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef CXSIGNALREPOSITORY_MQH
#define CXSIGNALREPOSITORY_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\Interfaces\IRepository.mqh"
#include "..\Interfaces\IDatabase.mqh"
#include "..\Models\CXSignal.mqh"

/**
 * @class CXDbMapper
 * @brief DatabaseColumnXXX 함수들을 타입별로 오버로딩하여 매크로에서 안전하게 호출 가능하도록 함.
 */
class CXDbMapper {
public:
   static void Fill(int req, int idx, string& var)   { DatabaseColumnText(req, idx, var); }
   static void Fill(int req, int idx, int& var)      { DatabaseColumnInteger(req, idx, var); }
   static void Fill(int req, int idx, double& var)   { DatabaseColumnDouble(req, idx, var); }
   static void Fill(int req, int idx, long& var)     { DatabaseColumnLong(req, idx, var); }
   static void Fill(int req, int idx, ulong& var)    { long l; if(DatabaseColumnLong(req, idx, l)) var = (ulong)l; }
   static void Fill(int req, int idx, datetime& var) {
      string dt_str;
      if(DatabaseColumnText(req, idx, dt_str)) var = StringToTime(dt_str);
   }
};

/**
 * @class CXSqlMapper
 * @brief 값을 SQLite 쿼리용 문자열로 변환하는 오버로딩 함수 집합.
 */
class CXSqlMapper {
public:
   static string ToSql(string v)   { return "'" + v + "'"; }
   static string ToSql(double v)   { return DoubleToString(v, 5); }
   static string ToSql(long v)     { return (string)v; }
   static string ToSql(ulong v)    { return (string)v; }
   static string ToSql(int v)      { return (string)v; }
   static string ToSql(datetime v) { return "datetime('" + TimeToString(v, TIME_DATE|TIME_SECONDS) + "')"; }
};

class CXSignalRepository : public IRepository {
private:
   IDatabase* m_db;
   
   //--- 고정 쿼리 핸들 캐싱 (Performance Optimization)
   int        m_hActiveSignals;
   int        m_hSignalBySid;

   int GetColumnIndex(int req, string name) {
      int count = DatabaseColumnsCount(req);
      string name_upper = name;
      StringToUpper(name_upper);
      
      for(int i = 0; i < count; i++) {
         string col_name;
         if(DatabaseColumnName(req, i, col_name)) {
            string col_upper = col_name;
            StringToUpper(col_upper);
            if(col_upper == name_upper) return i;
         }
      }
      return -1;
   }

public:
   CXSignalRepository(IDatabase* db) : m_db(db), 
      m_hActiveSignals(INVALID_HANDLE), 
      m_hSignalBySid(INVALID_HANDLE) {}

   virtual ~CXSignalRepository() {
      if(m_hActiveSignals != INVALID_HANDLE) DatabaseFinalize(m_hActiveSignals);
      if(m_hSignalBySid != INVALID_HANDLE)  DatabaseFinalize(m_hSignalBySid);
   }

   virtual void SaveSignal(ICXSignal* signal) override {
      if(IS_INVALID(signal) || IS_INVALID(m_db)) return;
      CXSignal* sig = CX_CAST(CXSignal, signal);
      if(IS_INVALID(sig)) return;

      string columns = "";
      string values = "";

      //--- [SSOT] SIGNAL_SCHEMA_FIELDS 매크로와 CXSqlMapper 오버로딩을 이용한 동적 SQL 생성
      #define X(type, name, dbType, getter) \
         if(#name != "id") { \
            columns += (columns == "" ? "" : ", ") + #name; \
            string val = (#name == "updated") ? "datetime('now','localtime')" : CXSqlMapper::ToSql(sig.name); \
            values += (values == "" ? "" : ", ") + val; \
         }
      SIGNAL_SCHEMA_FIELDS
      #undef X

      string sql = "INSERT OR REPLACE INTO signals (" + columns + ") VALUES (" + values + ")";
      m_db.Execute(sql);
   }

   virtual void LoadParam(ICXParam* param) override {
      // Implementation for loading dynamic parameters
   }

   virtual int GetStatusBySid(const string sid) override {
      if(IS_INVALID(m_db) || sid == "") return -1;
      string sql = StringFormat("SELECT xe_status FROM signals WHERE sid='%s'", sid);
      int handle = m_db.GetHandle();
      int req = DatabasePrepare(handle, sql);
      int status = -1;
      if(req != INVALID_HANDLE) {
         if(DatabaseRead(req)) DatabaseColumnInteger(req, 0, status);
         DatabaseFinalize(req);
      }
      return status;
   }

   virtual bool UpdateStatus(ICXSignal* signal) override {
      if(IS_INVALID(m_db) || IS_INVALID(signal)) return false;

      string sMsg = signal.GetStatusMsg();
      StringReplace(sMsg, "'", "''"); // [v14.25] Escape single quotes for SQL

      string tagVal = signal.GetTag();
      StringReplace(tagVal, "'", "''");

      // [v16.19 Race-Condition Safeguard]
      // ATSE의 상태 보고가 App의 의도(1)를 덮어쓰지 않도록 MAX 함수를 사용 (Regression 방지)
      // [v18.15 Fix] ticket 필드 누락 수정: 티켓 번호 할당 시 DB에 즉시 반영되어야 함
      string sql = StringFormat(
                      "UPDATE signals SET xe_status=%d, xe_status_msg='%s', ticket=%I64u, xa_entry=MAX(xa_entry, %d), xa_exit=MAX(xa_exit, %d), tag='%s', updated=datetime('now','localtime') WHERE sid='%s'",
                      signal.GetStatus(), sMsg, signal.GetTicket(), signal.GetXAEntry(), signal.GetXAExit(), tagVal, signal.GetSid()
                   );
      return m_db.Execute(sql);
   }

   /**
    * @brief [v16.19] ATSE에 의한 명시적 의도 업데이트
    * @details 수동 종료 감지 등 ATSE가 주도적으로 의도를 변경해야 할 때 사용 (MAX 가드 우회)
    */
   virtual bool ForceUpdateIntent(ICXSignal* signal) override {
      if(IS_INVALID(m_db) || IS_INVALID(signal)) return false;

      string sMsg = signal.GetStatusMsg();
      StringReplace(sMsg, "'", "''");

      string tagVal = signal.GetTag();
      StringReplace(tagVal, "'", "''");

      string sql = StringFormat(
                      "UPDATE signals SET xe_status=%d, xe_status_msg='%s', xa_entry=%d, xa_exit=%d, tag='%s', updated=datetime('now','localtime') WHERE sid='%s'",
                      signal.GetStatus(), sMsg, signal.GetXAEntry(), signal.GetXAExit(), tagVal, signal.GetSid()
                   );
      return m_db.Execute(sql);
   }
   virtual bool DeleteBySid(const string sid) override {
      if(IS_INVALID(m_db) || sid == "") return false;
      string sql = StringFormat("DELETE FROM signals WHERE sid='%s'", sid);
      return m_db.Execute(sql);
   }

   virtual ICXSignal* GetSignalByCnoSno(int cno, int sno, string symbol) override {
      if(IS_INVALID(m_db)) return NULL;
      string sql = StringFormat("SELECT * FROM signals WHERE cno=%d AND sno=%d AND symbol='%s' ORDER BY id DESC LIMIT 1", 
                                cno, sno, symbol);
      int hQuery = DatabasePrepare(m_db.GetHandle(), sql);
      if(hQuery == INVALID_HANDLE) return NULL;
      
      CArrayObj list;
      ICXSignal* sig = NULL;
      if(FetchSignals(hQuery, GetPointer(list)) > 0) {
         sig = CX_CAST(ICXSignal, list.Detach(0));
      }
      DatabaseFinalize(hQuery);
      return sig;
   }

   //--- [Test Runner Helpers]
   bool Add(ICXSignal* sig) { SaveSignal(sig); return true; }
   
   /**
    * @brief [v19.40] 테스트용 전체 초기화 (Truncate)
    */
   bool TruncateSignals() {
      if(IS_INVALID(m_db)) return false;
      return m_db.Execute("DELETE FROM signals");
   }

   bool DeleteSignalByCnoSno(int cno, int sno, string symbol) {
      if(IS_INVALID(m_db)) return false;
      string sql = StringFormat("DELETE FROM signals WHERE cno=%d AND sno=%d AND symbol='%s'", 
                                cno, sno, symbol);
      return m_db.Execute(sql);
   }

   virtual int LoadActiveSignals(CArrayObj* list) override {
      if (IS_INVALID(m_db) || IS_INVALID(list)) return 0;

      // [v14.34 Fix] EXIT-FIRST Priority Mandate: xa_exit=1은 XE_ERROR(99)를 우회하여 로드 및 최상단 정렬
      string sql = StringFormat("SELECT * FROM signals WHERE ((xa_entry > %d OR xa_exit > %d) AND xe_status < %d AND xe_status <> %d) OR (xa_exit = %d AND xe_status = %d) ORDER BY (xa_exit = %d) DESC, updated ASC", 
                                XA_RAW, XA_RAW, XE_CLOSED_SIGNAL, XE_ERROR, XA_ACTIVE, XE_ERROR, XA_ACTIVE);

      int hQuery = DatabasePrepare(m_db.GetHandle(), sql);
      if(hQuery == INVALID_HANDLE) return 0;

      int count = FetchSignals(hQuery, list);
      DatabaseFinalize(hQuery);
      return count;
   }

   virtual int LoadEntrySignals(CArrayObj* list) override {
      if (IS_INVALID(m_db) || IS_INVALID(list)) return 0;
      string sql = StringFormat("SELECT * FROM signals WHERE xa_entry = %d AND xe_status = %d ORDER BY updated ASC",
                                XA_ACTIVE, XE_READY);
      int hQuery = DatabasePrepare(m_db.GetHandle(), sql);

      if(hQuery == INVALID_HANDLE) return 0;
      int count = FetchSignals(hQuery, list);
      DatabaseFinalize(hQuery);
      return count;
   }

   virtual int LoadExitSignals(CArrayObj* list) override {
      if (IS_INVALID(m_db) || IS_INVALID(list)) return 0;
      // [v14.34 Fix] EXIT-FIRST Priority Mandate: xa_exit=1은 XE_ERROR(99)를 포함하여 로드
      string sql = StringFormat("SELECT * FROM signals WHERE xa_exit = %d AND (xe_status < %d OR xe_status = %d) ORDER BY updated ASC", 
                                XA_ACTIVE, XE_CLOSED_SIGNAL, XE_ERROR);
      int hQuery = DatabasePrepare(m_db.GetHandle(), sql);
      if(hQuery == INVALID_HANDLE) return 0;
      int count = FetchSignals(hQuery, list);
      DatabaseFinalize(hQuery);
      return count;
   }

   virtual ICXSignal* GetSignalBySid(const string sid) override {
      if (IS_INVALID(m_db) || sid == "") return NULL;

      if(m_hSignalBySid == INVALID_HANDLE) {
         string sql = "SELECT * FROM signals WHERE sid = ?";
         m_hSignalBySid = DatabasePrepare(m_db.GetHandle(), sql);
         if(m_hSignalBySid == INVALID_HANDLE) return NULL;
      } else {
         DatabaseReset(m_hSignalBySid);
      }

      DatabaseBind(m_hSignalBySid, 0, sid);
      
      CArrayObj list;
      if (FetchSignals(m_hSignalBySid, GetPointer(list)) > 0) {
         return CX_CAST(ICXSignal, list.Detach(0));
      }
      return NULL;
   }

private:
   int FetchSignals(int req, CArrayObj* list) {
      int count = 0;
      int idx = -1;
      while (DatabaseRead(req)) {
         CXSignal* sig = new CXSignal();

         //--- [SSOT] SIGNAL_SCHEMA_FIELDS 매크로와 CXDbMapper 오버로딩을 이용한 자동 매핑
         #define X(type, name, dbType, getter) \
            if((idx = GetColumnIndex(req, #name)) >= 0) CXDbMapper::Fill(req, idx, sig.name);
         SIGNAL_SCHEMA_FIELDS
         #undef X

         list.Add(sig);
         count++;
      }
      return count;
   }
};

#endif
