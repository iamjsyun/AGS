#ifndef CX_TASK_TRAIL_R_EXECUTE_MQH
#define CX_TASK_TRAIL_R_EXECUTE_MQH

#include "..\..\..\01_Core\Interfaces\IXTask.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\02_Domain\Models\CXParam.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\..\01_Core\Interfaces\IXOrderManager.mqh"
#include "..\..\..\01_Core\Interfaces\IXExitManager.mqh"
#include "..\..\..\01_Core\Defines\CXDefine.mqh"

/**
 * @class CXTaskTrail_R_Execute
 * @brief Executes actual trade (entry/liquidation) when a trailing trigger occurs
 * [v2.1 Smart PVB] Implementation of GetRequiredServices
 */
class CXTaskTrail_R_Execute : public IXTask {
private:
    ENUM_TRAIL_MODE  m_mode;
    IXOrderManager* m_orderMgr;

public:
    CXTaskTrail_R_Execute(ENUM_TRAIL_MODE mode) : m_mode(mode), m_orderMgr(NULL) {}
    
    virtual string Name() override { return (m_mode == TRAIL_MODE_ENTRY) ? "Trail_R_Execute_TE" : "Trail_R_Execute_TS"; }
    
    virtual string GetRequiredServices() override { return "order_mgr"; }

    virtual bool Bind(ICXContext* ctx) override {
        m_orderMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
        if(IS_INVALID(m_orderMgr)) return false;
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        int code = xp.GetInt();
        if(IS_INVALID(sig) || code <= 0) return TASK_CONTINUE;

        if(m_mode == TRAIL_MODE_ENTRY && code == 10) {
            sig.SetStatusMsg("TE Rebound: Executing Market Entry...");
            ulong oldTicket = (ulong)sig.GetTicket();
            m_orderMgr.DeleteOrder(xp, oldTicket);
            sig.SetTicket(0);
            sig.SetStatus(XE_READY);
            sig.SetType(ORDER_MARKET);
            if(m_orderMgr.ExecuteEntry(xp)) {
                sig.SetTag("ENTRY_TE_REBOUND");
                
                // [v2.4] Store actual entry price and mark as TE filled in Global Context
                ICXContext* globalCtx = CX_GET_OBJ(ctx, "global_ctx", ICXContext);
                if(IS_VALID(globalCtx)) {
                    string entryPriceKey = "TE_EntryPrice_" + sig.GetSid();
                    ICXParam* pEntry = new CXParam();
                    pEntry.SetDouble(sig.GetPriceOpen());
                    globalCtx.Set(entryPriceKey, pEntry);

                    string filledKey = "TE_Filled_" + sig.GetSid();
                    ICXParam* pFilled = new CXParam();
                    pFilled.SetInt(1);
                    globalCtx.Set(filledKey, pFilled);
                }

                XP_LOG_OK(xp, CXAuditFormatter::Build(Name(), xp, StringFormat("TE Market Fallback Success. Entry: %s", DoubleToString(sig.GetPriceOpen(), (int)SymbolInfoInteger(sig.GetSymbol(), SYMBOL_DIGITS)))));
                return 10;
            }
        } else if(m_mode == TRAIL_MODE_EXIT && code == 20) {
            XP_LOG_INFO(xp, CXAuditFormatter::Build(Name(), xp, "TS Retraction Triggered. Transitioning to Liquidation..."));
            return 20;
        }
        return TASK_CONTINUE;
    }
};

#endif
