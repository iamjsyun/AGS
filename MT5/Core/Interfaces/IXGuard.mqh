#ifndef IXGUARD_MQH
#define IXGUARD_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"
#include "ICXParam.mqh"
#include "ICXContext.mqh"

class IXGuard : public CObject {
public:
    virtual ~IXGuard() {}

    // Identification Validation
    virtual bool ValidateMagic(long magic) = 0;
    virtual bool ValidateSID(string sid) = 0;
    virtual bool ValidateGID(string gid) = 0;

    // Trading Metric Validation
    virtual bool   ValidatePrice(string symbol, double price) = 0;
    virtual bool   ValidateLot(string symbol, double lot) = 0;
    virtual bool   ValidateSlippage(int slippage) = 0;
    
    // Price & Point Processing
    virtual double PointsToPrice(string symbol, double points) const = 0;
    virtual double NormalizePrice(string symbol, double price) const = 0;
    virtual bool   ValidateStopLevel(string symbol, double base_price, double target_price) = 0;

    // String & Protocol Validation
    virtual bool ValidateComment(string comment) = 0;
    virtual bool ValidateCnoBinding(int cno, long magic) = 0;
    
    // Result Feedback
    virtual string GetLastError() const = 0;
    
    // General Validation
    virtual bool Check(ICXParam* xp, ICXContext* ctx) = 0;
};

#endif
