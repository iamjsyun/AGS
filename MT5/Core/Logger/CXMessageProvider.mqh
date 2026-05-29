#ifndef CXMESSAGEPROVIDER_MQH
#define CXMESSAGEPROVIDER_MQH

#include "..\Defines\CXDefine.mqh"
#include "..\Defines\CXMessageDictionary.mqh"
#include "..\Interfaces\ICXSignal.mqh"

/**
 * @class CXMessageProvider
 * @brief 상태 코드 및 메시지 통합 관리자
 * @details WPF(ATSA) 표준 메시지 형식 [SYS-xxx], [ERR-xxx]을 생성하고 Signal 객체에 업데이트함.
 */
class CXMessageProvider {
public:
    /**
     * @brief 신호 상태 및 메시지 동시 업데이트
     */
    static void UpdateStatus(ICXSignal* sig, int status, string raw_msg) {
        if(IS_INVALID(sig)) return;
        sig.SetStatus(status);
        sig.SetStatusMsg(raw_msg);
    }

    /**
     * @brief [SYS-xxx] 형식의 정형 메시지 생성 (포맷팅 지원)
     */
    static string Format(string code_msg, string detail = "") {
        if(detail == "") return code_msg;
        return code_msg + " (" + detail + ")";
    }

    /**
     * @brief 레이어별 청산 진행 메시지 생성
     */
    static string GetExitLayerMsg(int layer, string sid) {
        switch(layer) {
            case 1: return MSG_EXIT_TICKET_CLOSED;
            case 2: return MSG_EXIT_SWEEP_DONE;
            case 3: return MSG_EXIT_VERIFIED_CLEAN;
            default: return "[SYS-200] Exit processing...";
        }
    }
};

#endif
