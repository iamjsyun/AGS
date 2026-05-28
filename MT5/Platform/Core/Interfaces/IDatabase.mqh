#ifndef IDATABASE_MQH
#define IDATABASE_MQH

#include <Object.mqh>

/**
 * @class IDatabase
 * @brief 저수준 데이터베이스 엔진 인터페이스
 */
class IDatabase : public CObject {
public:
    virtual ~IDatabase() {}
    virtual bool Open(string name = "ATS.db", bool common = true) = 0;
    virtual void Close() = 0;
    virtual bool Execute(string sql) = 0;
    virtual int  GetHandle() = 0;
};

#endif
