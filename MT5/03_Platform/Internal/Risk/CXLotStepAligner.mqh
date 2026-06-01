#ifndef CXLOTSTEPALIGNER_MQH
#define CXLOTSTEPALIGNER_MQH

#include <Object.mqh>

/**
 * @class CXLotStepAligner
 * @brief [v1.0] Atomic class specialized in precision alignment according to broker volume step (Hyper-Atomization)
 */
class CXLotStepAligner : public CObject {
public:
    /**
     * @brief Align lot size to minimum unit and step (Truncation method)
     * @param lot Requested lot
     * @param minLot Minimum lot (e.g., 0.01)
     * @param lotStep Lot increment/decrement unit (e.g., 0.01)
     */
    static double Align(double lot, double minLot, double lotStep) {
        if(lot < minLot) return 0;
        if(lotStep <= 0) return lot;
        
        // Truncate after adding a small epsilon for precision compensation
        double aligned = minLot + MathFloor((lot - minLot) / lotStep + 0.0000001) * lotStep;
        
        // Automatic calculation of digits
        int digits = 0;
        if(lotStep < 0.1) digits = 2;
        else if(lotStep < 1.0) digits = 1;
        
        return NormalizeDouble(aligned, digits);
    }
};

#endif
