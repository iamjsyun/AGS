#ifndef CXTRAILINGENGINE_MQH
#define CXTRAILINGENGINE_MQH

#include <Object.mqh>
#include "..\..\Core\Defines\CXDefine.mqh"

enum ENUM_TRAIL_STATE {
    TRAIL_STATE_INACTIVE,   // 비활성 (활성화 조건 감시 중)
    TRAIL_STATE_ACTIVE,     // 활성 (극점 갱신 중)
    TRAIL_STATE_TRIGGERED,  // 트리거 달성 (진입 또는 청산 실행 조건 만족)
    TRAIL_STATE_COMPLETED   // 실행 완료 및 종료
};

enum ENUM_TRAIL_MODE {
    TRAIL_MODE_ENTRY,       // 진입 트레일링 (진트)
    TRAIL_MODE_EXIT         // 청산/익절 트레일링 (익트)
};

/**
 * @class CXTrailingEngine
 * @brief 진트(TE)와 익트(TS) 모두에서 활용할 수 있는 상태머신 기반의 고도화된 트레일링 엔진
 */
class CXTrailingEngine : public CObject {
private:
    ENUM_TRAIL_MODE  m_mode;
    ENUM_TRAIL_STATE m_state;
    int              m_direction;       // CX_DIR_BUY (1) 또는 CX_DIR_SELL (-1)
    double           m_point;           // 심볼 포인트 크기
    
    double           m_start_threshold; // 활성화 트리거 포인트 (te_start / ts_start)
    double           m_step;            // 갱신/반등 포인트 (te_step / ts_step)
    double           m_limit;           // 최대 허용 한계 포인트 (te_limit / ts_limit)
    
    double           m_reference_price; // 최초 기준가 (진입 신호가 또는 포지션 개시가)
    double           m_extreme_price;   // 추적된 극점 (최저가 또는 최고가)
    double           m_activation_price;// 활성화 임계 가격

public:
    CXTrailingEngine(ENUM_TRAIL_MODE mode, int direction, double point)
        : m_mode(mode), m_direction(direction), m_point(point),
          m_state(TRAIL_STATE_INACTIVE), m_reference_price(0.0),
          m_extreme_price(0.0), m_activation_price(0.0),
          m_start_threshold(0.0), m_step(0.0), m_limit(0.0) {}

    //--- 초기화 및 파라미터 구성
    void Configure(double refPrice, double startThreshold, double step, double limit = 0.0) {
        m_reference_price = refPrice;
        m_start_threshold = startThreshold;
        m_step = step;
        m_limit = limit;
        m_state = TRAIL_STATE_INACTIVE;
        
        // 방향에 따른 활성화 가격 결정
        double dir_sign = (m_direction == CX_DIR_BUY) ? 1.0 : -1.0;
        if (m_mode == TRAIL_MODE_ENTRY) {
            // BUY 진트: 가격 하락 시 활성화 (신호가 - te_start)
            // SELL 진트: 가격 상승 시 활성화 (신호가 + te_start)
            m_activation_price = m_reference_price - (m_start_threshold * m_point * dir_sign);
        } else {
            // BUY 익트: 가격 상승 시 활성화 (개시가 + ts_start)
            // SELL 익트: 가격 하락 시 활성화 (개시가 - ts_start)
            m_activation_price = m_reference_price + (m_start_threshold * m_point * dir_sign);
        }
        m_extreme_price = m_reference_price;
    }

    //--- 틱 데이터 업데이트 및 상태 계산
    ENUM_TRAIL_STATE Update(double currentPrice) {
        if (m_state == TRAIL_STATE_COMPLETED || m_state == TRAIL_STATE_TRIGGERED) 
            return m_state;

        double dir_sign = (m_direction == CX_DIR_BUY) ? 1.0 : -1.0;

        if (m_state == TRAIL_STATE_INACTIVE) {
            // 활성화 조건 감시
            bool is_activated = false;
            if (m_mode == TRAIL_MODE_ENTRY) {
                // 진트 활성화 조건: 가격이 활성화 선을 터치하거나 돌파
                is_activated = (m_direction == CX_DIR_BUY) ? (currentPrice <= m_activation_price) 
                                                           : (currentPrice >= m_activation_price);
            } else {
                // 익트 활성화 조건: 수익이 활성화 기준 이상 도달
                double profit = (currentPrice - m_reference_price) * dir_sign;
                is_activated = (profit >= m_start_threshold * m_point);
            }

            if (is_activated) {
                m_state = TRAIL_STATE_ACTIVE;
                m_extreme_price = currentPrice;
            }
        }

        if (m_state == TRAIL_STATE_ACTIVE) {
            // 극점 갱신 및 반등/되돌림 감시
            if (m_mode == TRAIL_MODE_ENTRY) {
                // 진트: 극점(최저/최고) 갱신
                if (m_direction == CX_DIR_BUY) {
                    if (currentPrice < m_extreme_price) m_extreme_price = currentPrice;
                    // 반등(Rebound) 감지: 최저가 대비 te_step 이상 상승 시 트리거
                    if (currentPrice - m_extreme_price >= m_step * m_point) {
                        m_state = TRAIL_STATE_TRIGGERED;
                    }
                } else {
                    if (currentPrice > m_extreme_price) m_extreme_price = currentPrice;
                    // 반락 감지: 최고가 대비 te_step 이상 하락 시 트리거
                    if (m_extreme_price - currentPrice >= m_step * m_point) {
                        m_state = TRAIL_STATE_TRIGGERED;
                    }
                }
            } else {
                // 익트: 극점(최고/최저) 갱신
                if (m_direction == CX_DIR_BUY) {
                    if (currentPrice > m_extreme_price) m_extreme_price = currentPrice;
                    // 되돌림 감지: 최고가 대비 ts_step 이상 하락 시 트리거
                    if (m_extreme_price - currentPrice >= m_step * m_point) {
                        m_state = TRAIL_STATE_TRIGGERED;
                    }
                } else {
                    if (currentPrice < m_extreme_price) m_extreme_price = currentPrice;
                    // 되돌림 감지: 최저가 대비 ts_step 이상 상승 시 트리거
                    if (currentPrice - m_extreme_price >= m_step * m_point) {
                        m_state = TRAIL_STATE_TRIGGERED;
                    }
                }
            }
        }

        return m_state;
    }

    //--- Getter/Setter
    ENUM_TRAIL_STATE GetState() const { return m_state; }
    void             SetCompleted() { m_state = TRAIL_STATE_COMPLETED; }
    double           GetExtreme() const { return m_extreme_price; }
};

#endif
