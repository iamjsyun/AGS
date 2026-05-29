#ifndef CX_SCENARIO_PARAM_MQH
#define CX_SCENARIO_PARAM_MQH

#include <Object.mqh>

/**
 * @class CXScenarioParam
 * @brief Self-Test 시나리오의 각 행 데이터를 저장하는 전용 DTO (v13.8 Granular)
 */
class CXScenarioParam : public CObject {
public:
    int      release_delay;
    string   action;
    string   sid;
    int      cno;
    int      sno;
    string   symbol;
    int      dir;
    int      type;
    double   lot;
    int      sl_pts;
    int      tp_pts;
    
    // [v13.8] Granular TE Parameters
    int      te_start;
    int      te_step;
    int      te_limit;
    
    // [v13.8] Granular TS Parameters
    int      ts_start;
    int      ts_step;

    string   exp_status; 
    string   comment;
    
    // 추적용 필드
    string   sid_used;

    CXScenarioParam() : release_delay(0), cno(0), sno(0), dir(0), type(0), lot(0), sl_pts(0), tp_pts(0), 
                        te_start(0), te_step(0), te_limit(0), 
                        ts_start(0), ts_step(0), 
                        exp_status(""), sid(""), sid_used("") {}
};

#endif
