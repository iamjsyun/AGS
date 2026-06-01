#ifndef IXTERMINALPLATFORM_MQH
#define IXTERMINALPLATFORM_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXSignal.mqh"

/**
 * @interface IXTerminalPlatform
 * @brief Physical platform interface dedicated to MT5 terminal and broker integration (includes standard logging and exception handling)
 */
class IXTerminalPlatform : public CObject {
public:
    virtual ~IXTerminalPlatform() {}

    //--- Set Magic Number
    virtual void SetMagic(ulong magic) = 0;

    //--- 1. Trade Operations
    virtual bool PositionOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) = 0;
    virtual bool OrderOpen(ICXParam* xp, ICXSignal* sig, double price, double sl, double tp) = 0;
    virtual bool PositionModify(ICXParam* xp, ulong ticket, double sl, double tp) = 0;
    virtual bool OrderModify(ICXParam* xp, ulong ticket, double price, double sl, double tp) = 0;
    virtual bool PositionClose(ICXParam* xp, ulong ticket) = 0;
    virtual bool OrderDelete(ICXParam* xp, ulong ticket) = 0;

    //--- 2. Account Information
    virtual double GetAccountBalance() = 0;
    virtual double GetAccountEquity() = 0;
    virtual double GetAccountMargin() = 0;
    virtual double GetAccountFreeMargin() = 0;
    virtual long   GetAccountLeverage() = 0;

    //--- 3. Asset Queries
    virtual bool IsPositionExists(ulong ticket) = 0;
    virtual bool IsOrderExists(ulong ticket) = 0;
    virtual double GetPositionVolume(ulong ticket) = 0;
    virtual double GetPositionPriceOpen(ulong ticket) = 0;
    virtual double GetPositionSL(ulong ticket) = 0;
    virtual double GetPositionTP(ulong ticket) = 0;
    virtual double GetOrderVolume(ulong ticket) = 0;
    virtual double GetOrderPriceOpen(ulong ticket) = 0;
    virtual double GetOrderSL(ulong ticket) = 0;
    virtual double GetOrderTP(ulong ticket) = 0;
    virtual int    GetPositionsTotal() = 0;
    virtual int    GetOrdersTotal() = 0;
    virtual double GetPositionProfit(ulong ticket) = 0;
    virtual string GetPositionComment(ulong ticket) = 0;
    virtual string GetOrderComment(ulong ticket) = 0;
    virtual int    CheckHistoryClosure(ulong ticket, string &outReason) = 0;
    virtual bool   VerifyPhysicalAbsence(ulong magic, string sid) = 0;
    virtual ulong  GetTicketBySid(ulong magic, string sid) = 0;
    virtual bool   SweepBySid(ICXParam* xp, ulong magic, string sid) = 0;
    virtual bool   SweepByMagic(ICXParam* xp, ulong magic) = 0;
    
    //--- 4. Compatibility and Additional Utilities
    virtual ulong GetLastResultDeal() = 0;
    virtual ulong GetLastResultOrder() = 0;
    virtual uint  GetLastRetCode() = 0;
    virtual string GetLastRetCodeDescription() = 0;

    //--- 5. Mock Detection
    virtual bool IsMock() { return false; }

    //--- 6. History Access (for subdivision/analyzer)
    virtual bool HistorySelect(datetime from, datetime to) = 0;
    virtual int  HistoryDealsTotal() = 0;
    virtual ulong HistoryDealGetTicket(int index) = 0;
    virtual long HistoryDealGetInteger(ulong ticket, int prop) = 0; // Use int for property to avoid enum dependency
    virtual string HistoryDealGetString(ulong ticket, int prop) = 0;
    virtual int  HistoryOrdersTotal() = 0;
    virtual ulong HistoryOrderGetTicket(int index) = 0;
    virtual long HistoryOrderGetInteger(ulong ticket, int prop) = 0;
};

#endif
