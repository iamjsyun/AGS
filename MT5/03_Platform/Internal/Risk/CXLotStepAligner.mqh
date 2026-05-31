#ifndef CXLOTSTEPALIGNER_MQH
#define CXLOTSTEPALIGNER_MQH

#include <Object.mqh>

/**
 * @class CXLotStepAligner
 * @brief [v1.0] 브로커 로트 스텝(Volume Step)에 따른 정밀 정렬 전문 원자 클래스 (Hyper-Atomization)
 */
class CXLotStepAligner : public CObject {
public:
    /**
     * @brief 로트 사이즈를 최소 단위 및 스텝에 맞춰 정렬 (절사 방식)
     * @param lot 요청 로트
     * @param minLot 최소 로트 (예: 0.01)
     * @param lotStep 로트 증감 단위 (예: 0.01)
     */
    static double Align(double lot, double minLot, double lotStep) {
        if(lot < minLot) return 0;
        if(lotStep <= 0) return lot;
        
        // 정밀도 보정을 위한 소량의 엡실론 가산 후 절사
        double aligned = minLot + MathFloor((lot - minLot) / lotStep + 0.0000001) * lotStep;
        
        // 자릿수 자동 계산
        int digits = 0;
        if(lotStep < 0.1) digits = 2;
        else if(lotStep < 1.0) digits = 1;
        
        return NormalizeDouble(aligned, digits);
    }
};

#endif
