#ifndef CXUI_MQH
#define CXUI_MQH

#include <Object.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include "..\Interfaces\ICXContext.mqh"
#include "..\Interfaces\ICXSignal.mqh"
#include "..\Interfaces\IRepository.mqh"
#include "..\Interfaces\ICXPriceManager.mqh"
#include "..\Macros\CXMacros.mqh"
#include "..\..\03_Platform\Session\CXTerminalScanner.mqh"
#include "..\..\02_Domain\Models\CXTerminalAsset.mqh"

// Per-row UI object structure used for rendering (Covers 10 slots)
struct MqlUIElement {
    CChartObjectLabel      Line1;       // SID, integer settings, status display
    CChartObjectLabel      Line2;       // Calculated price values
};

/**
 * @class CXUI
 * @brief AGS on-chart real-time session info dashboard visualization component
 */
class CXUI : public CObject {
private:
    ICXContext*       m_ctx;              // Service context dependency
    MqlUIElement      m_elements[10];     // Manages up to 10 session slots
    
    // UI style configuration
    color             m_color_text;
    int               m_font_size;
    string            m_font_name;

    // Chart layout coordinates
    int               m_x_offset;
    int               m_y_offset;
    int               m_slot_spacing;
    int               m_line_spacing;

public:
    /**
     * @brief Constructor
     */
    CXUI(ICXContext* ctx) : m_ctx(ctx),
                            m_color_text(clrGold),
                            m_font_size(11),
                            m_font_name("Consolas"),
                            m_x_offset(20),
                            m_y_offset(60),
                            m_slot_spacing(40),
                            m_line_spacing(16) {
    }

    /**
     * @brief Destructor
     */
    virtual ~CXUI() override {
        Deinitialize();
    }

    /**
     * @brief Initial creation and initialization of chart label resources
     */
    bool Initialize() {
        for(int i = 0; i < 10; i++) {
            string nameL1 = StringFormat("CXUI_%d_L1", i);
            string nameL2 = StringFormat("CXUI_%d_L2", i);

            int yPosL1 = m_y_offset + (i * m_slot_spacing);
            int yPosL2 = yPosL1 + m_line_spacing;

            // Line 1 creation and default settings
            if(!m_elements[i].Line1.Create(0, nameL1, 0, m_x_offset, yPosL1)) return false;
            m_elements[i].Line1.Font(m_font_name);
            m_elements[i].Line1.FontSize(m_font_size);
            m_elements[i].Line1.Color(m_color_text);
            m_elements[i].Line1.Description(" ");

            // Line 2 creation and default settings
            if(!m_elements[i].Line2.Create(0, nameL2, 0, m_x_offset, yPosL2)) return false;
            m_elements[i].Line2.Font(m_font_name);
            m_elements[i].Line2.FontSize(m_font_size);
            m_elements[i].Line2.Color(m_color_text);
            m_elements[i].Line2.Description(" ");
        }
        ChartRedraw(0);
        return true;
    }

    /**
     * @brief Complete destruction of chart resources (Leak prevention)
     */
    void Deinitialize() {
        for(int i = 0; i < 10; i++) {
            m_elements[i].Line1.Delete();
            m_elements[i].Line2.Delete();
        }
        ChartRedraw(0);
    }
    
    /**
     * @brief Real-time re-rendering (Called periodically in OnTick / OnTimer)
     */
    void Refresh() {
        if(IS_INVALID(m_ctx)) return;

        IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
        if(IS_INVALID(repo)) return;

        ICXPriceManager* priceMgr = CX_GET_OBJ(m_ctx, "price_mgr", ICXPriceManager);
        ICXAssetManager* assetMgr = CX_GET_OBJ(m_ctx, "asset_mgr", ICXAssetManager);

        CXTerminalScanner scanner;
        CArrayObj* assetList = new CArrayObj();
        assetList.FreeMode(true);
        scanner.ScanAll(assetList);

        CArrayObj* activeList = new CArrayObj();
        activeList.FreeMode(true);

        for(int i = 0; i < assetList.Total(); i++) {
            CXTerminalAsset* asset = CX_CAST(CXTerminalAsset, assetList.At(i));
            if(IS_VALID(asset)) {
                bool duplicate = false;
                for(int j = 0; j < activeList.Total(); j++) {
                    ICXSignal* existing = CX_CAST(ICXSignal, activeList.At(j));
                    if(IS_VALID(existing) && existing.GetSid() == asset.sid) {
                        duplicate = true;
                        break;
                    }
                }
                if(duplicate) continue;

                ICXSignal* sig = repo.GetSignalBySid(asset.sid);
                if(IS_VALID(sig)) {
                    activeList.Add(sig);
                }
            }
        }

        int renderCount = MathMin(activeList.Total(), 10);

        for(int i = 0; i < 10; i++) {
            if(i < renderCount) {
                CXTerminalAsset* asset = CX_CAST(CXTerminalAsset, assetList.At(i));
                ICXSignal* sig = CX_CAST(ICXSignal, activeList.At(i));
                if(IS_VALID(sig) && IS_VALID(asset)) {
                    UpdateSlot(i, sig, asset.ticket, priceMgr, assetMgr);
                } else {
                    ClearSlot(i);
                }
            } else {
                ClearSlot(i);
            }
        }

        SAFE_DELETE(assetList);
        SAFE_DELETE(activeList);
        ChartRedraw(0);
    }

private:
    /**
     * @brief Bind and output active signal data to individual slots
     */
    void UpdateSlot(int slotIdx, ICXSignal* sig, ulong terminalTicket, ICXPriceManager* priceMgr, ICXAssetManager* assetMgr) {
        string symbol = sig.GetSymbol();
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double dirSign = (sig.GetDir() == CX_DIR_BUY) ? -1.0 : 1.0;
        double calcDir = (sig.GetDir() == CX_DIR_BUY) ? 1.0 : -1.0; // BUY: Advantage if price goes DOWN (for entry) or UP (for profit)
        
        ulong ticket = (terminalTicket > 0) ? terminalTicket : sig.GetTicket();

        // Status determination
        bool isPosition = (sig.GetStatus() >= XE_EXECUTED && sig.GetStatus() < XE_CLOSED_SIGNAL);

        ICXTradingSession* session = IS_VALID(assetMgr) ? assetMgr.FindSessionBySid(sig.GetSid()) : NULL;
        bool isTrailing = false;
        if(IS_VALID(session)) {
            int sState = session.GetState();
            if(sState == SESSION_TRAILING_ENTRY || sState == SESSION_TRAILING_STOP) {
                isTrailing = true;
            }
        }

        string txtL1 = StringFormat("%s%s  %d | %03d | %d  [%s]",
                                    isTrailing ? "▶ " : "",
                                    sig.GetSid(),
                                    (int)sig.GetTEStart(),
                                    (int)sig.GetTEStep(),
                                    (int)sig.GetTELimit(),
                                    GetStateName((ENUM_XE_STATUS)sig.GetStatus()) + (isTrailing ? "*TR" : ""));

        string txtL2 = "";
        if(isPosition) {
            // [v2.7] Position Dashboard: ENT: {entry} SIG: {discovery} ADV: {diff} TP: {tp}
            double entPrice = (IS_VALID(assetMgr)) ? assetMgr.GetCurrentPriceOpen(ticket, true) : sig.GetPriceOpen();
            double sigPrice = sig.GetPrice(); // Discovery Market Price
            double tpPrice  = (IS_VALID(assetMgr)) ? assetMgr.GetCurrentTP(ticket) : sig.GetPriceTP();
            
            ICXParam* pTEStart = m_ctx.GetParam("TE_StartPrice_" + sig.GetSid());
            double teStart = IS_VALID(pTEStart) ? pTEStart.GetDouble() : sigPrice;
            
            // Advantage calculation: Discovery Mkt vs Actual Entry (Positive means improved)
            double advPts = (sigPrice > 0 && entPrice > 0) ? (sigPrice - entPrice) * calcDir : 0;
            
            txtL2 = StringFormat(" ┗━ ENT:%s SIG:%s ADV:%+.1f TP:%s",
                                 DoubleToString(entPrice, digits),
                                 DoubleToString(sigPrice, digits),
                                 advPts / point,
                                 DoubleToString(tpPrice, digits));
        } else {
            // [v2.7] Pending Order Dashboard: LIMIT: {entry} ESTART: {STR}, {TRACK}
            double limitPrice = (IS_VALID(assetMgr)) ? assetMgr.GetCurrentPriceOpen(ticket, false) : sig.GetPriceOpen();
            
            ICXParam* pTEStart = m_ctx.GetParam("TE_StartPrice_" + sig.GetSid());
            double teStart = IS_VALID(pTEStart) ? pTEStart.GetDouble() : 0;
            
            ICXParam* pExt = m_ctx.GetParam("TE_Extreme_" + sig.GetSid());
            double extreme = IS_VALID(pExt) ? pExt.GetDouble() : 0;

            txtL2 = StringFormat(" ┗━ LIMIT:%s ESTART:%s %s" ,
                                 DoubleToString(limitPrice, digits),
                                 (teStart > 0) ? DoubleToString(teStart, digits) : "---",
                                 (extreme > 0) ? DoubleToString(extreme, digits) : "---");
        }

        // Apply color
        color slotColor = clrWhite;
        if(sig.GetDir() == CX_DIR_BUY) slotColor = isPosition ? clrDodgerBlue : clrWheat;
        else if(sig.GetDir() == CX_DIR_SELL) slotColor = isPosition ? clrTomato : clrLightCoral;
        
        m_elements[slotIdx].Line1.Color(slotColor);
        m_elements[slotIdx].Line2.Color(isTrailing ? clrRed : slotColor);

        m_elements[slotIdx].Line1.Description(txtL1);
        m_elements[slotIdx].Line2.Description(txtL2);
    }

    /**
     * @brief Clear unused slots and handle with spaces (Replace with " ")
     */
    void ClearSlot(int slotIdx) {
        m_elements[slotIdx].Line1.Description(" ");
        m_elements[slotIdx].Line2.Description(" ");
    }

    /**
     * @brief Engine state name formatting helper
     */
    string GetStateName(ENUM_XE_STATUS status) {
        switch(status) {
            case XE_READY:          return "READY";
            case XE_PENDING_REQ:    return "PEND_REQ";
            case XE_IN_TRANSIT:     return "TRANSIT";
            case XE_PENDING_PLACED: return "PENDING";
            case XE_EXECUTED:       return "ACTIVE";
            case XE_CLOSED_SIGNAL:  return "CLOSED";
            case XE_CLOSED_SL:      return "CLOSED_SL";
            case XE_CLOSED_TP:      return "CLOSED_TP";
            case XE_CLOSED_MANUAL:  return "CLSD_MAN";
            case XE_ERROR:          return "ERROR";
            default:                return "UNKNOWN";
        }
    }
};

#endif
