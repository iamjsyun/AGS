#ifndef ICXSYMBOLMANAGER_MQH
#define ICXSYMBOLMANAGER_MQH

#include <Object.mqh>

/**
 * @interface ICXSymbolManager
 * @brief 심볼 속성 및 규격 관리 전문 인터페이스 (SSOC: Symbol Properties)
 */
class ICXSymbolManager : public CObject {
public:
    virtual ~ICXSymbolManager() {}

    //-- 기본 속성 (캐싱 지원)
    virtual double GetPoint(string symbol) = 0;
    virtual int    GetDigits(string symbol) = 0;
    virtual double GetTickSize(string symbol) = 0;
    
    //-- 제약 조건 (캐싱 지원)
    virtual int    GetStopsLevel(string symbol) = 0;
    virtual int    GetFreezeLevel(string symbol) = 0;

    //-- 거래 명세 (Volume)
    virtual double GetMinLot(string symbol) = 0;
    virtual double GetMaxLot(string symbol) = 0;
    virtual double GetLotStep(string symbol) = 0;

    //-- 실시간 데이터
    virtual int    GetSpread(string symbol) = 0;

    //-- 틱 데이터 강제 갱신 (매 틱 시작 시 호출 권장)
    virtual void   Refresh(string symbol) = 0;
};

#endif
