#ifndef IXPRICETRACKER_MQH
#define IXPRICETRACKER_MQH

#include <Object.mqh>

/**
 * @class IXPriceTracker
 * @brief 실시간 고점/저점 및 변동성 추적 인터페이스
 */
class IXPriceTracker : public CObject {
public:
    virtual ~IXPriceTracker() {}
    
    virtual void   Update(double price) = 0;
    virtual double GetHighest() const = 0;
    virtual double GetLowest() const = 0;
    virtual void   Reset() = 0;
};

#endif
