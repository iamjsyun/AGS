#ifndef CXTICKSCRAPER_MQH
#define CXTICKSCRAPER_MQH

#include <Object.mqh>

/**
 * @class CXTickScraper
 * @brief [v1.0] Atomic class specialized in price rounding/truncation based on TickSize and Digits (Hyper-Atomization)
 * @details Contains only pure mathematical logic independent of MT5 API
 */
class CXTickScraper : public CObject {
public:
    /**
     * @brief Adjust price according to decimal places and tick size
     * @param price Original price
     * @param tickSize Tick size (e.g., 0.01)
     * @param digits Number of decimal places (e.g., 2)
     */
    static double Scrape(double price, double tickSize, int digits) {
        if(price <= 0) return 0;
        if(tickSize <= 0) return NormalizeDouble(price, digits);
        
        // Align to the nearest tick size via MathRound, then normalize decimal places
        double steps = MathRound(price / tickSize);
        return NormalizeDouble(steps * tickSize, digits);
    }
};

#endif
