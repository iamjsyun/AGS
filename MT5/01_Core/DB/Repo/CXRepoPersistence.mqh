/**
 * @file CXRepoPersistence.mqh
 * @brief [v1.0] Command-side implementations (CRUD) for CXSignalRepository
 */

public:
   virtual void SaveSignal(ICXSignal* signal) override {
      if(IS_INVALID(signal) || IS_INVALID(m_db)) return;
      CXSignal* sig = CX_CAST(CXSignal, signal);
      if(IS_INVALID(sig)) return;

      // [v20.1 Integrity Guard] Active Signal Overwrite Protection
      int currentStatus = GetStatusBySid(sig.GetSid());
      if(currentStatus >= XE_PENDING_REQ && currentStatus < XE_CLOSED_SIGNAL) {
          return; 
      }

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

   virtual bool DeleteBySid(const string sid) override {
      if(IS_INVALID(m_db) || sid == "") return false;
      string sql = StringFormat("DELETE FROM signals WHERE sid='%s'", sid);
      return m_db.Execute(sql);
   }

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

   //--- [Test Runner Helpers]
   bool Add(ICXSignal* sig) { SaveSignal(sig); return true; }
