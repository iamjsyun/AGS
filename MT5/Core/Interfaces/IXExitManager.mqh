#ifndef IXEXITMANAGER_MQH
#define IXEXITMANAGER_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "..\Models\CXSignal.mqh"

/**
 * @class IXExitManager
 * @brief 청산 및 자산 소멸을 위한 추상 인터페이스 (3-Layer Guard)
 */
class IXExitManager : public CObject {
public:
    virtual void SetMagic(ulong magic) = 0;
    virtual bool ExecuteExit(ICXParam* xp) = 0;
    virtual bool CloseByTicket(ICXParam* xp, ICXSignal* sig) = 0;
    virtual bool SweepBySid(ICXParam* xp, string sid) = 0;
    virtual bool SweepByMagic(ICXParam* xp, ulong magic) = 0;
    virtual bool VerifyPhysicalAbsence(string sid) = 0;
};

#endif
