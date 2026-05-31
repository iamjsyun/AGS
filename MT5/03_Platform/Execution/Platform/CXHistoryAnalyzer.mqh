#ifndef CXHISTORYANALYZER_MQH
#define CXHISTORYANALYZER_MQH

#include "..\..\..\01_Core\Interfaces\ICXHistoryAnalyzer.mqh"
#include "..\..\..\01_Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include <Trade\Trade.mqh>

/**
 * @class CXHistoryAnalyzer
 * @brief [v1.0] 히스토리 데이터 해석 전담 클래스 (Subdivision Phase 1)
 * @details MT5 히스토리 Deal 및 Order를 조회하여 청산 사유(SL/TP/CANCELED 등)를 판별함
 */
class CXHistoryAnalyzer : public ICXHistoryAnalyzer {
private:
    IXTerminalPlatform* m_terminal;

public:
    CXHistoryAnalyzer(IXTerminalPlatform* terminal) : m_terminal(terminal) {}
    virtual ~CXHistoryAnalyzer() override {}

    /**
     * @brief 티켓 번호를 기반으로 히스토리 데이터를 분석하여 청산 상태 반환
     */
    virtual int Analyze(ulong ticket, string &outReason) override {
        if(IS_INVALID(m_terminal)) {
            outReason = "Analyzer Error: Terminal Missing";
            return XE_UNKNOWN;
        }

        if(ticket <= 0) {
            outReason = "Invalid Ticket (0)";
            return XE_UNKNOWN;
        }

        //--- 1. Deal History 분석 (포지션 청산 건)
        if(m_terminal.HistorySelect(0, TimeCurrent())) {
            int total = m_terminal.HistoryDealsTotal();
            for(int i = 0; i < total; i++) {
                ulong dealTicket = m_terminal.HistoryDealGetTicket(i);
                
                // DEAL_POSITION_ID가 요청한 티켓과 일치하고, 나가는 방향(ENTRY_OUT)인 것 탐색
                if(m_terminal.HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == (long)ticket &&
                   m_terminal.HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                   
                    outReason = m_terminal.HistoryDealGetString(dealTicket, DEAL_COMMENT);
                    
                    // 주석 분석을 통한 청산 경로 판별 (SL/TP)
                    if(StringFind(outReason, "[sl]") >= 0 || StringFind(outReason, "sl") >= 0) {
                        outReason = "Closed by SL (" + outReason + ")";
                        return XE_CLOSED_SL;
                    } 
                    if(StringFind(outReason, "[tp]") >= 0 || StringFind(outReason, "tp") >= 0) {
                        outReason = "Closed by TP (" + outReason + ")";
                        return XE_CLOSED_TP;
                    }
                    
                    outReason = "Closed by Broker/Manual (" + outReason + ")";
                    return XE_CLOSED_SIGNAL;
                }
            }

            //--- 2. Order History 분석 (대기 주문 취소/만료 건)
            int totalOrders = m_terminal.HistoryOrdersTotal();
            for(int i = 0; i < totalOrders; i++) {
                ulong histTicket = m_terminal.HistoryOrderGetTicket(i);
                if(histTicket == ticket) {
                    ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)m_terminal.HistoryOrderGetInteger(histTicket, ORDER_STATE);
                    if(state == ORDER_STATE_CANCELED) {
                        outReason = "Pending Order Canceled by User/Broker";
                        return XE_CLOSED_SIGNAL;
                    }
                    if(state == ORDER_STATE_EXPIRED) {
                        outReason = "Pending Order Expired";
                        return XE_CLOSED_SIGNAL;
                    }
                }
            }
        }
        
        outReason = "Asset Not Found in Terminal/History";
        return XE_UNKNOWN;
    }
};

#endif
