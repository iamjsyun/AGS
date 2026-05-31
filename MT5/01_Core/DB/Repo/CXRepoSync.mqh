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
      // ATSE의 상태 보고가 App의 의도(1)를 덮어쓰지 않도록 MAX 함수를 사용 (Regression 방지)
      string sql = StringFormat(
                      "UPDATE signals SET xe_status=%d, xe_status_msg='%s', ticket=%I64u, xa_entry=MAX(xa_entry, %d), xa_exit=MAX(xa_exit, %d), tag='%s', updated=datetime('now','localtime') WHERE sid='%s'",
                      signal.GetStatus(), sMsg, signal.GetTicket(), signal.GetXAEntry(), signal.GetXAExit(), tagVal, signal.GetSid()
                   );
      return m_db.Execute(sql);
   }

   /**
    * @brief [v16.19] ATSE에 의한 명시적 의도 업데이트
    * @details 수동 종료 감지 시 ATSE가 주도적으로 의도를 변경해야 할 때 사용 (MAX 가드 우회)
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
