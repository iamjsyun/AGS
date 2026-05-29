#ifndef CXIDMANAGER_MQH
#define CXIDMANAGER_MQH

#include "CXDefine.mqh"

/**
 * @class CXIdManager
 * @brief SID/GID 규격 검증 및 데이터 추출 전문 매니저 (v8.2 Standard)
 * @details SID Format: CNO(4)-YYMMDDHH(8)-SNO(2)-GNO(2)-DIR(1)-TYPE(1) (Total 23 chars)
 */
class CXIdManager {
public:
    /**
     * @brief SID 규격 검증 (23자, 하이픈 위치 확인)
     */
    static bool ValidateSID(string sid) {
        if(StringLen(sid) != 23) return false;
        if(StringSubstr(sid, 4, 1) != "-" || StringSubstr(sid, 13, 1) != "-" || 
           StringSubstr(sid, 16, 1) != "-" || StringSubstr(sid, 19, 1) != "-" ||
           StringSubstr(sid, 21, 1) != "-") return false;
        return true;
    }

    /**
     * @brief SID에서 방향(Dir) 추출 (index 20)
     */
    static int ExtractDir(string sid) {
        if(!ValidateSID(sid)) return 0;
        string dirStr = StringSubstr(sid, 20, 1);
        return (int)StringToInteger(dirStr);
    }

    /**
     * @brief SID에서 주문 타입(Type) 추출 (index 22)
     */
    static int ExtractType(string sid) {
        if(!ValidateSID(sid)) return 0;
        string typeStr = StringSubstr(sid, 22, 1);
        return (int)StringToInteger(typeStr);
    }
};

#endif
