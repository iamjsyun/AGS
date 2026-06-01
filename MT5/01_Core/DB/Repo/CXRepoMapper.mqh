/**
 * @file CXRepoMapper.mqh
 * @brief [v1.0] Mapping utility classes for CXSignalRepository (Outside Class)
 */

#ifndef CXREPOMAPPER_MQH
#define CXREPOMAPPER_MQH

/**
 * @class CXDbMapper
 * @brief Overload DatabaseColumnXXX functions by type for safe macro-based access
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
 * @brief Collection of overloading functions for SQLite query string conversion
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

#endif
