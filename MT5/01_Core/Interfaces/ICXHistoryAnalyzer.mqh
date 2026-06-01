#ifndef ICXHISTORYANALYZER_MQH
#define ICXHISTORYANALYZER_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"

/**
 * @interface ICXHistoryAnalyzer
 * @brief [v1.0] Interface for determining liquidation reasons via history data analysis
 */
class ICXHistoryAnalyzer : public CObject {
public:
    virtual ~ICXHistoryAnalyzer() {}
    
    /**
     * @brief Analyzes history data (Deal/Order) based on ticket number and returns liquidation status and reason
     */
    virtual int Analyze(ulong ticket, string &outReason) = 0;
};

#endif
