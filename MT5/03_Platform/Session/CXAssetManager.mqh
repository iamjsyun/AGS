#ifndef CXASSETMANAGER_MQH
#define CXASSETMANAGER_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\01_Core\Interfaces\ICXTradingSession.mqh"
#include "..\..\01_Core\Interfaces\IXOrderManager.mqh"
#include "..\..\01_Core\Interfaces\IXPositionManager.mqh"
#include "..\..\01_Core\Interfaces\IXExitManager.mqh"
#include "..\..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\..\01_Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\01_Core\Logger\CXAuditFormatter.mqh"
#include "..\..\01_Core\App\CXTransaction.mqh"

/**
 * @class CXAssetRecord
 * @brief [v18.30] Lightweight DTO holding only the physical properties of an asset
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
 * @brief [v18.31] Manager responsible for terminal physical asset existence assurance, asset data synchronization, and unit session management
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
        AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Transaction Start");
        if(IS_INVALID(m_orderMgr) || IS_INVALID(xp)) return 0;
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return 0;

        if(FindSessionBySid(sig.GetSid()) != NULL || IsAssetLive(sig.GetSid())) {
            XP_LOG_ERROR(xp, StringFormat("[ASSET-MGR] Entry Rejected. SID %s already active.", sig.GetSid()));
            return 0;
        }

        // [v1.4 Atomic Transaction Pattern]
        CXEntryTransaction* tx = new CXEntryTransaction(xp, m_globalRepo, m_orderMgr, m_factory);
        if(IS_INVALID(tx)) return 0;

        ulong ticket = 0;
        if(tx.Execute()) {
            ticket = sig.GetTicket();
            if(ticket > 0) {
                CXAssetRecord* rec = new CXAssetRecord(ticket, sig.GetSid());
                rec.symbol = sig.GetSymbol(); rec.lot = sig.GetLot(); rec.price_open = sig.GetPriceOpen();
                m_assets.Add(rec);
                AssetManagerDebugLog("CXAssetManager::ExecuteEntry() - Transaction Success");
            }
        }
        delete tx;
        return ticket;
    }

    virtual bool ExecuteExit(ICXParam* xp, string sid) override {
        AssetManagerDebugLog("CXAssetManager::ExecuteExit() - Transaction Start");
        if(IS_INVALID(m_exitMgr) || IS_INVALID(xp)) return false;

        CXAssetRecord* rec = FindRecordBySid(sid);
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) {
            sig = m_globalRepo.GetSignalBySid(sid);
            if(IS_VALID(sig)) xp.SetSignal(sig);
        }

        if(IS_VALID(sig)) SyncToSignal(sig);

        // [v1.4 Atomic Transaction Pattern]
        CXExitTransaction* tx = new CXExitTransaction(xp, m_globalRepo, m_exitMgr);
        if(IS_INVALID(tx)) return false;

        bool success = false;
        if(tx.Execute()) {
            if(IS_VALID(rec)) RemoveRecordBySid(sid);
            PurgeTaskBySid(sid);
            success = true;
            AssetManagerDebugLog("CXAssetManager::ExecuteExit() - Transaction Success");
        }
        delete tx;
        return success;
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

    // --- [Asset SSOC] ---
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
