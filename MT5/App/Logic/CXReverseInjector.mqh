#ifndef CXREVERSEINJECTOR_MQH
#define CXREVERSEINJECTOR_MQH

#include "..\..\Platform\Core\Interfaces\ICXContext.mqh"
#include "..\..\Platform\Core\Interfaces\ICXParam.mqh"
#include "..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\Platform\Core\Interfaces\IDatabase.mqh"
#include "..\..\Platform\Core\Interfaces\ICXAssetManager.mqh"
#include "..\..\Platform\Core\Interfaces\ICXTradingSession.mqh"
#include "..\..\Platform\Core\Models\CXSignal.mqh"
#include "..\..\Platform\Core\Models\CXTerminalAsset.mqh"
#include "..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "CXTerminalScanner.mqh"
#include <Object.mqh>

/**
 * @class CXReverseInjector
 * @brief 터미널의 실물 자산을 기반으로 세션을 역으로 복구/생성 담당 (v18.30 AssetManager Integration)
 */
class CXReverseInjector : public CObject {
private:
    CXTerminalScanner*      m_scanner;
    IRepository*            m_repo;
    ICXAssetManager*        m_manager;
    ICXConfig*              m_config;
    IDatabase*              m_db;

public:
    CXReverseInjector(CXTerminalScanner* scanner, IRepository* repo, ICXAssetManager* manager, ICXConfig* config, IDatabase* db) 
        : m_scanner(scanner), m_repo(repo), m_manager(manager), m_config(config), m_db(db) {}

    /**
     * @brief [v11.3 / GEMINI.md] Apply options from SQLite database `channel_options` table
     */
    void ApplyChannelOptions(CXSignal* sig, int cno, int dir, bool isOrder) {
        if(IS_INVALID(m_db) || IS_INVALID(sig)) return;

        string sql = StringFormat("SELECT buy_entry_offset, sell_entry_offset, tp_points, sl_points, ts_trigger, ts_step, ikte_start, ikte_step FROM channel_options WHERE cno=%d", cno);
        int handle = m_db.GetHandle();
        int req = DatabasePrepare(handle, sql);
        
        bool found = false;
        double buy_offset = 0, sell_offset = 0, tp = 0, sl = 0, ik_start = 0, ik_step = 0;
        int ts_trig = 0, ts_st = 0;

        if(req != INVALID_HANDLE) {
            if(DatabaseRead(req)) {
                found = true;
                DatabaseColumnDouble(req, 0, buy_offset); DatabaseColumnDouble(req, 1, sell_offset);
                DatabaseColumnDouble(req, 2, tp); DatabaseColumnDouble(req, 3, sl);
                DatabaseColumnInteger(req, 4, ts_trig); DatabaseColumnInteger(req, 5, ts_st);
                DatabaseColumnDouble(req, 6, ik_start); DatabaseColumnDouble(req, 7, ik_step);
            }
            DatabaseFinalize(req);
        }

        if(found) {
            sig.SetCno(cno); sig.SetDir(dir);
            if(isOrder) {
                double offset = (dir == CX_DIR_BUY) ? buy_offset : sell_offset;
                sig.SetTEStart(offset); sig.SetTEStep(100.0); sig.SetTELimit(1000.0); sig.SetTEInterval(1);
            } else {
                sig.SetTEStart(0.0); sig.SetTEStep(0.0); sig.SetTELimit(0.0); sig.SetTEInterval(0);
                sig.SetIkTeStart(ik_start); sig.SetIkTeStep(ik_step);
            }
            sig.SetTP(tp); sig.SetSL(sl); sig.SetTSStart(ts_trig); sig.SetTSStep(ts_st);
        }
    }

    /**
     * @brief 스캔 및 역주입 실행 (Zombie Recovery)
     */
    void Pulse(ICXParam* xp) {
        if(IS_INVALID(m_scanner) || IS_INVALID(m_repo) || IS_INVALID(m_manager)) return;

        CArrayObj terminalAssets;
        if(m_scanner.ScanAll(GetPointer(terminalAssets)) <= 0) return;

        for(int i = 0; i < terminalAssets.Total(); i++) {
            CXTerminalAsset* asset = CX_CAST(CXTerminalAsset, terminalAssets.At(i));
            if(IS_INVALID(asset)) continue;

            string sid = asset.sid;
            if(IS_VALID(m_config) && !m_config.IsTargetMagic(asset.magic)) continue;

            // 0. 이미 해당 SID가 매니저 목록에서 관리 중인지 확인
            if(m_manager.IsAssetLive(sid)) continue;

            // 1. DB에서 해당 SID의 신호 정보 조회
            ICXSignal* sig = m_repo.GetSignalBySid(sid);
            
            if(IS_INVALID(sig) || sig.GetStatus() >= XE_CLOSED_SIGNAL) {
                CXSignal* fakeSig = new CXSignal();
                fakeSig.SetSid(sid); fakeSig.symbol = asset.symbol;
                fakeSig.ticket = asset.ticket; fakeSig.magic = asset.magic; fakeSig.lot = asset.lot;
                
                int dir = (asset.type == (int)ORDER_TYPE_BUY || asset.type == (int)ORDER_TYPE_BUY_LIMIT) ? CX_DIR_BUY : CX_DIR_SELL;
                fakeSig.SetDir(dir); fakeSig.SetType((ENUM_CX_ORDER_TYPE)asset.type);
                
                bool isOrder = true;
                if(PositionSelectByTicket(asset.ticket)) {
                    fakeSig.SetPriceOpen(PositionGetDouble(POSITION_PRICE_OPEN));
                    fakeSig.SetSL(PositionGetDouble(POSITION_SL)); fakeSig.SetTP(PositionGetDouble(POSITION_TP));
                    isOrder = false;
                } else if(OrderSelect(asset.ticket)) {
                    fakeSig.UpdatePriceSignal(OrderGetDouble(ORDER_PRICE_OPEN));
                    fakeSig.SetSL(OrderGetDouble(ORDER_SL)); fakeSig.SetTP(OrderGetDouble(ORDER_TP));
                }
                
                string parts[];
                if(StringSplit(sid, '-', parts) >= 1) ApplyChannelOptions(fakeSig, (int)StringToInteger(parts[0]), dir, isOrder);
                
                fakeSig.SetStatus(XE_QUARANTINED); 
                m_repo.SaveSignal(fakeSig);
                if(IS_VALID(sig)) delete sig;
                sig = fakeSig;
            }

            // 2. 세션 동적 생성 및 주입
            CXParam sp; sp.SetSignal(sig);
            ICXTradingSession* session = m_manager.CreateSession(GetPointer(sp));
            if(IS_VALID(session)) {
                session.InjectState(CX_CAST(CXSignal, sig));
            } else if(IS_VALID(sig)) delete sig;
        }
    }
};

#endif
