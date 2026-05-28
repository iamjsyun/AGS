#ifndef IXORDERMANAGER_MQH
#define IXORDERMANAGER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"

/**
 * @class IXOrderManager
 * @brief 주문 실행 및 수정을 위한 추상 인터페이스
 */
class IXOrderManager : public CObject {
public:
    virtual void SetMagic(ulong magic) = 0;
    virtual void Pulse(ICXParam* xp) = 0;
    virtual bool ExecuteEntry(ICXParam* xp) = 0;
    virtual bool ExecuteExit(ICXParam* xp) = 0;
    virtual bool ModifyOrder(ICXParam* xp, ulong ticket, double price, double sl, double tp) = 0;
    virtual bool ModifyPosition(ICXParam* xp, ulong ticket, double sl, double tp) = 0;
    virtual bool DeleteOrder(ICXParam* xp, ulong ticket) = 0;
    virtual void ScanAndBind(ICXParam* xp, CObject* sessionMgr) = 0;
    
    // [v13.4 UAF Standard]
    virtual string GetAuditString(ICXParam* xp, string actionLabel = "") = 0;
};

#endif
