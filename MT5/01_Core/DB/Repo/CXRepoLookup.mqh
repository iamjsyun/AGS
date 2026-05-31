/**
 * @file CXRepoLookup.mqh
 * @brief [v1.1] Query-side implementations (Single Record Lookup) for CXSignalRepository
 *
 * [Document History]
 * v1.0: Initial implementation
 * v1.1: Fix GetSignalBySid returning NULL due to DatabaseBind issue (switched to StringFormat)
 */

public:
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

   virtual ICXSignal* GetSignalBySid(const string sid) override {
      if (IS_INVALID(m_db) || sid == "") {
         RepositoryDebugLog(StringFormat("[DB-DEBUG] GetSignalBySid: Aborted. m_db valid: %s, sid: '%s'", (string)IS_VALID(m_db), sid));
         return NULL;
      }

      // [v1.1 Fix] DatabaseBind ? issue - switching to direct injection for SIDs
      string sql = StringFormat("SELECT * FROM signals WHERE sid = '%s'", sid);
      int hQuery = DatabasePrepare(m_db.GetHandle(), sql);
      
      if(hQuery == INVALID_HANDLE) {
         RepositoryDebugLog(StringFormat("[DB-DEBUG] GetSignalBySid: DatabasePrepare failed. Error code: %d, sql: '%s'", GetLastError(), sql));
         return NULL;
      }
      
      CArrayObj list;
      ICXSignal* sig = NULL;
      int count = FetchSignals(hQuery, GetPointer(list));
      RepositoryDebugLog(StringFormat("[DB-DEBUG] GetSignalBySid: sid='%s', FetchSignals count: %d", sid, count));
      
      if (count > 0) {
         sig = CX_CAST(ICXSignal, list.Detach(0));
      }
      
      DatabaseFinalize(hQuery);
      return sig;
   }
