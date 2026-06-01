/**
 * @file CXRepoInternal.mqh
 * @brief [v1.0] Internal class members for CXSignalRepository (Included inside class)
 */

private:
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

   void RepositoryDebugLog(string msg) {
      int h = FileOpen("debug_log.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
      if(h != INVALID_HANDLE) {
         FileSeek(h, 0, SEEK_END);
         FileWriteString(h, msg + "\r\n");
         FileClose(h);
      }
   }

   int FetchSignals(int req, CArrayObj* list) {
      int count = 0;
      int idx = -1;
      while (DatabaseRead(req)) {
         CXSignal* sig = new CXSignal();

         //--- [SSOT] Automatic mapping using SIGNAL_SCHEMA_FIELDS macro and CXDbMapper overloading
         #define X(type, name, dbType, getter) \
            if((idx = GetColumnIndex(req, #name)) >= 0) CXDbMapper::Fill(req, idx, sig.name);
         SIGNAL_SCHEMA_FIELDS
         #undef X

         list.Add(sig);
         count++;
      }
      return count;
   }
