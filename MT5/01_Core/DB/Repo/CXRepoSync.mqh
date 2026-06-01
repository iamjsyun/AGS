/**
 * @file CXRepoSync.mqh
 * @brief [v1.0] Status synchronization implementations for CXSignalRepository
 */

public:
   virtual bool UpdateStatus(ICXSignal* signal) override {
      if(IS_INVALID(m_db) || IS_INVALID(signal)) return false;

      string sMsg = signal.GetStatusMsg();
      StringReplace(sMsg, "'", "''"); // [v14.25] Escape single quotes for SQL

      string tagVal = signal.GetTag();
      StringReplace(tagVal, "'", "''");

      // [v16.19 Race-Condition Safeguard]
      // Use MAX function to ensure ATSE's status report does not overwrite App's intention (Prevent regression)
      string sql = StringFormat(
                      "UPDATE signals SET xe_status=%d, xe_status_msg='%s', ticket=%I64u, xa_entry=MAX(xa_entry, %d), xa_exit=MAX(xa_exit, %d), tag='%s', updated=datetime('now','localtime') WHERE sid='%s'",
                      signal.GetStatus(), sMsg, signal.GetTicket(), signal.GetXAEntry(), signal.GetXAExit(), tagVal, signal.GetSid()
                   );
      return m_db.Execute(sql);
   }

   /**
    * @brief [v16.19] Explicit intention update by ATSE
    * @details Used when ATSE needs to proactively change the intention upon detecting manual shutdown (Bypass MAX guard)
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
