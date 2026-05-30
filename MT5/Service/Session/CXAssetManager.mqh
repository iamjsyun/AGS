#ifndef CXASSETMANAGER_MQH
#define CXASSETMANAGER_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\..\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Core\Interfaces\ICXTradingSession.mqh"
#include "..\..\Core\Interfaces\IXOrderManager.mqh"
#include "..\..\Core\Interfaces\IXPositionManager.mqh"
#include "..\..\Core\Interfaces\IXExitManager.mqh"
#include "..\..\Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\Core\Macros\CXMacros.mqh"
#include "..\..\Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXAssetRecord
 * @brief [v18.30] 자산의 물리적 속성만을 보유하는 경량 DTO
 */
class CXAssetRecord : public CObject {
public:
    ulong  ticket;
    string sid;
    string symbol;
    double lot;
    double price_open;
    double price_sl;
    double price_tp;
    int    type;

    CXAssetRecord(ulong t, string s) : ticket(t), sid(s), symbol(""), lot(0), price_open(0), price_sl(0), price_tp(0), type(0) {}
};

/**
 * @class CXAssetManager
 * @brief [v18.31] 터미널 물리 자산의 실존 보증, 인벤토리 동기화 및 단위 태스크 관리를 총괄하는 관리자
 */
class CXAssetManager : public ICXAssetManager {
private:
    CArrayObj*          m_assets;       
    CArrayObj*          m_tasks;        
    
    IRepository*        m_globalRepo;
    ICXContext*         m_globalContext;
    ICXServiceFactory*  m_factory;
    IXOrderManager*     m_orderMgr;
    IXPositionManager*  m_posMgr;
    IXExitManager*      m_exitMgr;
    IXTerminalPlatform* m_terminal;

public:
    CXAssetManager() : m_globalRepo(NULL), m_globalContext(NULL), m_factory(NULL), 
                      m_orderMgr(NULL), m_posMgr(NULL), m_exitMgr(NULL), m_terminal(NULL) {
        m_assets = new CArrayObj();
        m_tasks = new CArrayObj();
    }

    virtual ~CXAssetManager() {
        SAFE_DELETE(m_tasks);
        SAFE_DELETE(m_assets);
        m_orderMgr = NULL;
        m_posMgr = NULL;
        m_exitMgr = NULL;
    }

    virtual void Initialize(IRepository* repo, ICXContext* ctx, ICXServiceFactory* factory) override {
        m_globalRepo = repo;
        m_globalContext = ctx;
        m_factory = factory;
        m_orderMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
        m_posMgr = CX_GET_OBJ(ctx, "pos_mgr", IXPositionManager);
        m_exitMgr = CX_GET_OBJ(ctx, "exit_mgr", IXExitManager);
        m_terminal = CX_GET_OBJ(ctx, "terminal_platform", IXTerminalPlatform);
    }

    void AssetManagerDebugLog(string msg) {
        int h = FileOpen("debug_log.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
        if(h != INVALID_HANDLE) {
            FileSeek(h, 0, SEEK_END);
            FileWriteString(h, msg + "\r\n");
            FileClose(h);
        } else {
            Print("[DEBUGLOG-ERR] Failed to write debug_log.txt in AssetManager. Code: ", GetLastError());
        }
    }

    virtual ulong ExecuteEntry(ICXParam* xp) override {
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Start");
        if(IS_INVALID(m_orderMgr) || IS_INVALID(xp)) { AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Abort: invalid orderMgr or xp"); return 0; }
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) { AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Abort: invalid signal"); return 0; }

        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Duplicate SID check");
        if(FindSessionBySid(sig.GetSid()) != NULL || IsAssetLive(sig.GetSid())) {
            XP_LOG_ERROR(xp, StringFormat("[ASSET-MGR] Entry Rejected. SID %s already active.", sig.GetSid()));
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Abort: duplicate SID active");
            return 0;
        }

        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Creating price manager");
        ICXPriceManager* priceMgr = m_factory.CreatePriceManager(m_globalContext);
        if(IS_VALID(priceMgr)) {
            string sym = sig.GetSymbol(); int dir = sig.GetDir();
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Calculating exec price");
            double execPrice = priceMgr.CalculateExecPrice(xp, sym, dir, sig.GetType(), sig.GetTELimit());
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Calculating base price");
            double basePrice = (sig.GetType() == ORDER_MARKET) ? priceMgr.GetMarketPrice(sym, dir) : execPrice;
            sig.SetPriceOpen(execPrice);
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Calculating SL");
            sig.SetPriceSL(priceMgr.CalculateSL(xp, sym, dir, basePrice, sig.GetSL()));
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Calculating TP");
            sig.SetPriceTP(priceMgr.CalculateTP(xp, sym, dir, basePrice, sig.GetTP()));
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Deleting price manager");
            SAFE_DELETE(priceMgr);
        }
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Price manager setup complete");

        // [v1.2 Atomic Lock Mandate] 브로커 호출 전 '요청 중' 상태로 DB 즉시 고정 (중복 진입 방어)
        sig.SetStatus(XE_PENDING_REQ);
        sig.SetStatusMsg("Sending Request to Broker...");
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Updating signal status in DB");
        if(IS_VALID(m_globalRepo)) m_globalRepo.UpdateStatus(sig);
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Signal status updated in DB");

        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Calling m_orderMgr.ExecuteEntry");
        bool success = m_orderMgr.ExecuteEntry(xp);
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - m_orderMgr.ExecuteEntry finished, result: " + (string)success);
        if(success) {
            ulong ticket = sig.GetTicket();
            AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Ticket received: " + (string)ticket);
            if(ticket > 0) {
                CXAssetRecord* rec = new CXAssetRecord(ticket, sig.GetSid());
                rec.symbol = sig.GetSymbol(); rec.lot = sig.GetLot(); rec.price_open = sig.GetPriceOpen();
                m_assets.Add(rec);
                AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Success");
                return ticket;
            }
        }
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - End (failed to execute or get ticket)");
        return 0;
    }
virtual bool ExecuteExit(ICXParam* xp, string sid) override {
    if(IS_INVALID(m_exitMgr)) return false;

    // 1. 내부 목록에서 해당 SID의 레코드 찾기
    CXAssetRecord* rec = FindRecordBySid(sid);

    // [v1.0 Scenario H] Pre-Close Shadowing Sync
    // Ensure the signal object in the parameter context is fully synchronized with terminal reality before exit.
    ICXSignal* sig = xp.GetSignal();
    if(IS_INVALID(sig)) {
        sig = m_globalRepo.GetSignalBySid(sid);
        if(IS_VALID(sig)) xp.SetSignal(sig);
    }

    if(IS_VALID(sig)) {
        // Force rescan of terminal volume, price, SL, TP to handle manual drift
        SyncToSignal(sig);
    }

    // 2. 만약 장부에 없으면, 터미널을 직접 확인 (레거시 대응 및 무결성 보충)
    if(IS_INVALID(rec)) {
        // 터미널 플랫폼을 통해 해당 SID의 티켓 검색
        ulong ticket = m_terminal.GetTicketBySid(0, sid); // Magic=0은 전수 검색 시도
        if(ticket <= 0) {
            // 물리적으로도 없으면 이미 청산된 것으로 간주 (성공 반환하여 DB 정리 유도)
            return true; 
        }
        // 물리 티켓이 있으면 청산 진행 (xp에 이미 sig가 세팅됨)
        if(IS_VALID(sig)) {
            bool res = m_exitMgr.ExecuteExit(xp);
            // Note: If sig was created locally here, it should be deleted, 
            // but xp might be sharing it. Actually, sig from repo should be deleted if not managed by session.
            // However, ExecuteExit normally uses the session's signal.
            return res;
        }
        return false;
    }

    if(m_exitMgr.ExecuteExit(xp)) {
        // 성공 시 레코드 및 해당 태스크 제거
        RemoveRecordBySid(sid);
        PurgeTaskBySid(sid);
        return true;
    }
    return false;
}
    // --- [Queries] ---
    virtual bool IsAssetLive(string sid) override { return (FindRecordBySid(sid) != NULL); }
    virtual bool IsPositionExists(ulong ticket) override { return (IS_VALID(m_terminal) && m_terminal.IsPositionExists(ticket)); }
    virtual bool IsOrderExists(ulong ticket) override { return (IS_VALID(m_terminal) && m_terminal.IsOrderExists(ticket)); }
    virtual bool IsAssetExists(ulong ticket, int type) override {
        if(ticket <= 0) return false;
        if(IsPositionExists(ticket)) return true;
        if(type != ORDER_MARKET && IsOrderExists(ticket)) return true;
        return false;
    }

    // --- [Inventory SSOC] ---
    virtual bool SyncToSignal(ICXSignal* sig) override {
        if(IS_INVALID(sig) || IS_INVALID(m_terminal)) return false;
        ulong ticket = (ulong)sig.GetTicket();
        if(ticket <= 0) return false;

        if(m_terminal.IsPositionExists(ticket)) {
            sig.SetLot(m_terminal.GetPositionVolume(ticket));
            sig.SetPriceOpen(m_terminal.GetPositionPriceOpen(ticket));
            sig.SetSL(m_terminal.GetPositionSL(ticket));
            sig.SetTP(m_terminal.GetPositionTP(ticket));
            return true;
        }
        if(m_terminal.IsOrderExists(ticket)) {
            sig.SetLot(m_terminal.GetOrderVolume(ticket));
            sig.UpdatePriceSignal(m_terminal.GetOrderPriceOpen(ticket));
            sig.SetSL(m_terminal.GetOrderSL(ticket));
            sig.SetTP(m_terminal.GetOrderTP(ticket));
            return true;
        }
        return false;
    }

    virtual int CheckHistoryClosure(ulong ticket, string &reason) override {
        return (IS_VALID(m_terminal)) ? m_terminal.CheckHistoryClosure(ticket, reason) : XE_UNKNOWN;
    }

    virtual double GetCurrentVolume(ulong ticket, bool isPosition) override {
        if(IS_INVALID(m_terminal)) return 0;
        if(isPosition) return m_terminal.GetPositionVolume(ticket);
        return m_terminal.GetOrderVolume(ticket);
    }

    virtual double GetCurrentPriceOpen(ulong ticket, bool isPosition) override {
        if(IS_INVALID(m_terminal)) return 0;
        if(isPosition) return m_terminal.GetPositionPriceOpen(ticket);
        return m_terminal.GetOrderPriceOpen(ticket);
    }

    virtual double GetCurrentSL(ulong ticket) override {
        if(IS_INVALID(m_terminal)) return 0;
        if(m_terminal.IsPositionExists(ticket)) return m_terminal.GetPositionSL(ticket);
        if(m_terminal.IsOrderExists(ticket)) return m_terminal.GetOrderSL(ticket);
        return 0;
    }

    virtual double GetCurrentTP(ulong ticket) override {
        if(IS_INVALID(m_terminal)) return 0;
        if(m_terminal.IsPositionExists(ticket)) return m_terminal.GetPositionTP(ticket);
        if(m_terminal.IsOrderExists(ticket)) return m_terminal.GetOrderTP(ticket);
        return 0;
    }

    virtual double GetCurrentProfit(ulong ticket) override {
        if(IS_INVALID(m_terminal)) return 0;
        return m_terminal.GetPositionProfit(ticket);
    }

    // --- [Session Management] ---
    virtual ICXTradingSession* CreateSession(ICXParam* xp) override {
        if(IS_INVALID(m_factory) || IS_INVALID(xp)) return NULL;
        ICXTradingSession* session = m_factory.CreateSession(xp);
        if(IS_VALID(session)) { 
            if(session.Bind()) {
                m_tasks.Add(session); 
                return session; 
            } else {
                PrintFormat("[FATAL] Session Bind Failed for SID: %s", session.GetSid());
                SAFE_DELETE(session);
            }
        }
        return NULL;
    }

    virtual ICXTradingSession* FindSessionBySid(const string sid) override {
        for(int i = 0; i < m_tasks.Total(); i++) {
            ICXTradingSession* session = CX_CAST(ICXTradingSession, m_tasks.At(i));
            if(IS_VALID(session) && session.GetSid() == sid) return session;
        }
        return NULL;
    }

    virtual void Pulse(ICXParam* xp) override {
        // [v1.0 Priority Scan] Scan and bind terminal assets BEFORE pulsing sessions to avoid stale state checks
        if(IS_VALID(m_orderMgr)) m_orderMgr.ScanAndBind(xp, GetPointer(this));
        if(IS_VALID(m_posMgr))   m_posMgr.ScanAndBind(xp, GetPointer(this));

        int total = m_tasks.Total();
        for(int i = 0; i < total; i++) {
            ICXTradingSession* session = CX_CAST(ICXTradingSession, m_tasks.At(i));
            if(IS_VALID(session)) { if(IS_VALID(xp)) xp.Reset(); session.Pulse(xp); }
        }
        PurgeInactiveTasks();

        // [v11.4 Mandate] Dangling Pointer Protection
        if(IS_VALID(xp)) {
            xp.SetSignal(NULL);
            xp.Reset();
        }
    }

private:
    CXAssetRecord* FindRecordBySid(string sid) {
        for(int i = 0; i < m_assets.Total(); i++) {
            CXAssetRecord* rec = CX_CAST(CXAssetRecord, m_assets.At(i));
            if(IS_VALID(rec) && rec.sid == sid) return rec;
        }
        return NULL;
    }

    void RemoveRecordBySid(string sid) {
        CArrayObj toKeep; toKeep.FreeMode(false);
        CArrayObj toDelete; toDelete.FreeMode(true);

        int total = m_assets.Total();
        for(int i = 0; i < total; i++) {
            CXAssetRecord* rec = CX_CAST(CXAssetRecord, m_assets.At(i));
            if(IS_VALID(rec) && rec.sid == sid) toDelete.Add(rec);
            else toKeep.Add(rec);
        }

        m_assets.FreeMode(false);
        m_assets.Clear();
        for(int i = 0; i < toKeep.Total(); i++) m_assets.Add(toKeep.At(i));
        m_assets.FreeMode(true);
        // toDelete is automatically cleared on scope exit, deleting the objects
    }

    void PurgeTaskBySid(string sid) {
        CArrayObj toKeep; toKeep.FreeMode(false);
        CArrayObj toDelete; toDelete.FreeMode(true);

        int total = m_tasks.Total();
        for(int i = 0; i < total; i++) {
            ICXTradingSession* session = CX_CAST(ICXTradingSession, m_tasks.At(i));
            if(IS_VALID(session) && session.GetSid() == sid) toDelete.Add(session);
            else toKeep.Add(session);
        }

        m_tasks.FreeMode(false);
        m_tasks.Clear();
        for(int i = 0; i < toKeep.Total(); i++) m_tasks.Add(toKeep.At(i));
        m_tasks.FreeMode(true);
    }

    void PurgeInactiveTasks() {
        CArrayObj toKeep; toKeep.FreeMode(false);
        CArrayObj toDelete; toDelete.FreeMode(true);

        int total = m_tasks.Total();
        for(int i = 0; i < total; i++) {
            ICXTradingSession* session = CX_CAST(ICXTradingSession, m_tasks.At(i));
            if(IS_VALID(session) && !session.IsActive()) toDelete.Add(session);
            else toKeep.Add(session);
        }

        m_tasks.FreeMode(false);
        m_tasks.Clear();
        for(int i = 0; i < toKeep.Total(); i++) m_tasks.Add(toKeep.At(i));
        m_tasks.FreeMode(true);
    }
};

#endif
