#ifndef ICXHISTORYANALYZER_MQH
#define ICXHISTORYANALYZER_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"

/**
 * @interface ICXHistoryAnalyzer
 * @brief [v1.0] 히스토리 데이터 분석을 통한 청산 사유 판별기 인터페이스
 */
class ICXHistoryAnalyzer : public CObject {
public:
    virtual ~ICXHistoryAnalyzer() {}
    
    /**
     * @brief 티켓 번호를 기반으로 히스토리 데이터(Deal/Order)를 분석하여 청산 상태 및 사유 반환
     */
    virtual int Analyze(ulong ticket, string &outReason) = 0;
};

#endif
