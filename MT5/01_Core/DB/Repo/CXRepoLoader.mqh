/**
 * @file CXRepoLoader.mqh
 * @brief [v1.0] Bulk loading implementations for CXSignalRepository
 */

public:
   virtual int LoadActiveSignals(CArrayObj* list) override {
      if (IS_INVALID(m_db) || IS_INVALID(list)) return 0;

      // [v14.34 Fix] EXIT-FIRST Priority Mandate
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
      // [v14.34 Fix] EXIT-FIRST Priority Mandate
      string sql = StringFormat("SELECT * FROM signals WHERE xa_exit = %d AND (xe_status < %d OR xe_status = %d) ORDER BY updated ASC", 
                                XA_ACTIVE, XE_CLOSED_SIGNAL, XE_ERROR);
      int hQuery = DatabasePrepare(m_db.GetHandle(), sql);
      if(hQuery == INVALID_HANDLE) return 0;
      int count = FetchSignals(hQuery, list);
      DatabaseFinalize(hQuery);
      return count;
   }
