#ifndef ICXORDERVALIDATOR_MQH
#define ICXORDERVALIDATOR_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXSignal.mqh"

/**
 * @interface ICXOrderValidator
 * @brief [v1.0] Interface for verifying price and distance (StopsLevel) integrity before order transmission
 */
class ICXOrderValidator : public CObject {
public:
    virtual ~ICXOrderValidator() {}
    
    /**
     * @brief Verifies if the requested entry price adheres to the broker's minimum distance (StopsLevel) and corrects it if necessary
     */
    virtual double ValidateExecPrice(ICXParam* xp, string symbol, int dir, int type, double requestedPrice) = 0;

    /**
     * @brief Verifies if SL/TP prices meet the minimum allowed distance
     */
    virtual bool ValidateStops(ICXParam* xp, string symbol, int dir, double openPrice, double sl, double tp) = 0;
};

#endif
