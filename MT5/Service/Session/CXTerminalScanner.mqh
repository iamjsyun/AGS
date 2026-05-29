#ifndef CXTERMINALSCANNER_MQH
#define CXTERMINALSCANNER_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\..\Core\Models\CXTerminalAsset.mqh"

/**
 * @class CXTerminalScanner
 * @brief 터미널의 물리적 자산(포지션/주문) 전수 조사 담당
 */
class CXTerminalScanner {
public:
    CXTerminalScanner() {}
    ~CXTerminalScanner() {}

    /**
     * @brief 특정 SID를 가진 실물 자산이 존재하는지 확인 (중복 주입 방지용)
     */
    bool IsSidExists(string sid) {
        if(sid == "") return false;

        int totalPos = PositionsTotal();
        for(int i = 0; i < totalPos; i++) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                if(PositionGetString(POSITION_COMMENT) == sid) return true;
            }
        }

        int totalOrd = OrdersTotal();
        for(int i = 0; i < totalOrd; i++) {
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket)) {
                if(OrderGetString(ORDER_COMMENT) == sid) return true;
            }
        }
        return false;
    }

    /**
     * @brief 현재 터미널의 모든 관리 대상 자산을 스캔하여 리스트로 반환
     */
    int ScanAll(CArrayObj* list) {
        if(CheckPointer(list) == POINTER_INVALID) return 0;
        int count = 0;

        //-- 1. 활성 포지션 스캔
        int totalPos = PositionsTotal();
        for(int i = 0; i < totalPos; i++) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                string sid = PositionGetString(POSITION_COMMENT);
                if(sid != "") {
                    CXTerminalAsset* p = new CXTerminalAsset();
                    p.sid = sid;
                    p.ticket = ticket;
                    p.symbol = PositionGetString(POSITION_SYMBOL);
                    p.magic = (int)PositionGetInteger(POSITION_MAGIC);
                    
                    // [v14.35] Extract actual volume and direction
                    p.lot = PositionGetDouble(POSITION_VOLUME);
                    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                    p.type = (posType == POSITION_TYPE_BUY) ? (int)ORDER_TYPE_BUY : (int)ORDER_TYPE_SELL;
                    
                    list.Add(p);
                    count++;
                }
            }
        }

        //-- 2. 대기 주문 스캔
        int totalOrd = OrdersTotal();
        for(int i = 0; i < totalOrd; i++) {
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket)) {
                string sid = OrderGetString(ORDER_COMMENT);
                if(sid != "") {
                    CXTerminalAsset* p = new CXTerminalAsset();
                    p.sid = sid;
                    p.ticket = ticket;
                    p.symbol = OrderGetString(ORDER_SYMBOL);
                    p.magic = (int)OrderGetInteger(ORDER_MAGIC);
                    p.lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
                    p.type = (int)OrderGetInteger(ORDER_TYPE);
                    list.Add(p);
                    count++;
                }
            }
        }

        return count;
    }
};

#endif
