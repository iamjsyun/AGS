#ifndef CXPRICETRACKER_MQH
#define CXPRICETRACKER_MQH

#include "..\..\Core\Interfaces\IXPriceTracker.mqh"
#include <Object.mqh>

/**
 * @class CXPriceTracker
 * @brief ?ㅼ떆媛?怨좎젏/???異붿쟻湲?(Sandboxed)
 */
class CXPriceTracker : public IXPriceTracker {
private:
    double m_highest;
    double m_lowest;

public:
    CXPriceTracker() { Reset(); }
    virtual ~CXPriceTracker() {}

    virtual void Update(double price) override {
        if(m_highest == 0 || price > m_highest) m_highest = price;
        if(m_lowest  == 0 || price < m_lowest)  m_lowest  = price;
    }

    virtual double GetHighest() const override { return m_highest; }
    virtual double GetLowest() const override  { return m_lowest; }

    virtual void Reset() override {
        m_highest = 0;
        m_lowest  = 0;
    }
};

#endif


