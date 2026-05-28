#ifndef CX_TASK_PENDING_R_APPLY_MQH
#define CX_TASK_PENDING_R_APPLY_MQH

#include "..\..\..\Platform\Core\Interfaces\IXTask.mqh"
#include "..\..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXOrderManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\..\Platform\Core\Interfaces\IXGuard.mqh"
#include "..\..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXSymbolManager.mqh"
#include "..\..\..\Platform\Core\Interfaces\ICXPriceManager.mqh"

/**
 * @class CXTaskPending_R_Apply
 * @brief [Request] 계산된 가격을 브로커에 적용 및 DB 기록
 */
class CXTaskPending_R_Apply : public IXTask {
public:
    virtual string Name() override { return "Pending_R_Apply"; }
    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        ICXSignal* sig = xp.GetSignal();
        IXOrderManager* orderMgr = CX_GET_OBJ(ctx, "order_mgr", IXOrderManager);
        IRepository* repo = CX_GET_OBJ(ctx, "repo", IRepository);

        if(IS_INVALID(sig) || IS_INVALID(orderMgr)) {
            if(IS_VALID(sig) && IS_INVALID(orderMgr)) {
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "CRITICAL: order_mgr service is invalid in context!"));
            }
            return TASK_BREAK;
        }

        int flag = xp.GetInt(); 
        
        // [v1.2 Fix] 컨텍스트 영속 플래그 이중 체크 (Task 간 플래그 오염 방어)
        string reboundKey = "ReboundTriggered_" + sig.GetSid();
        ICXParam* pReb = ctx.GetParam(reboundKey);
        if(IS_VALID(pReb) && pReb.GetInt() == 10) flag = 10;
        
        // [v1.3 Diagnostic]
        if(flag == 10) {
            XP_LOG_INFO(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "Processing Market Fallback due to rebound..."));
            ulong oldTicket = (ulong)sig.GetTicket();
            
            // [v1.3 Fix] 실행 직전 상태 잠금 (Sequence 보호)
            sig.SetStatus(XE_IN_TRANSIT);
            sig.SetStatusMsg("Market Fallback: Deleting Pending Order...");
            if(IS_VALID(repo)) repo.UpdateStatus(sig);

            bool deleteSuccess = orderMgr.DeleteOrder(xp, oldTicket);
            
            // [v1.3 Resilience] 만약 삭제 실패 사유가 '이미 없는 오더' 등이라면 계속 진행
            if(!deleteSuccess) {
                uint retCode = 0;
                IXTerminalPlatform* terminal = CX_GET_OBJ(ctx, "terminal_platform", IXTerminalPlatform); // [v1.3.1 Fix] Terminal platform key corrected
                if(IS_VALID(terminal)) retCode = terminal.GetLastRetCode();
                
                XP_LOG_WARN(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, StringFormat("DeleteOrder failed (Code:%u). Verifying asset existence...", retCode)));
                
                ICXAssetManager* invMgr = CX_GET_OBJ(ctx, "asset_mgr", ICXAssetManager);
                if(IS_VALID(invMgr)) {
                    if(invMgr.IsPositionExists(oldTicket)) {
                        XP_LOG_OK(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "Order is already filled as position. Transitioning to ACTIVE."));
                        sig.SetStatus(XE_EXECUTED);
                        sig.SetStatusMsg("Market Fallback Entered (Already Filled)");
                        if(IS_VALID(repo)) repo.UpdateStatus(sig);
                        ctx.Remove(reboundKey);
                        return SESSION_ACTIVE;
                    }
                    if(!invMgr.IsOrderExists(oldTicket)) {
                        XP_LOG_WARN(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "Order is missing. Assuming deleted. Proceeding to Market Entry."));
                        deleteSuccess = true;
                    } else {
                        XP_LOG_WARN(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "Order still exists. Delete failed due to broker constraint. Retrying later..."));
                        return TASK_YIELD;
                    }
                }
            }

            if(deleteSuccess) { // 삭제 완료 (또는 이미 없음이 확인된 경우) 시장가 진입 시도
                sig.SetTEStart(sig.GetTELimit());
                sig.SetType(ORDER_MARKET); // 변경: 시장가 오더로 변경
                
                // 새로운 가격 및 SL/TP 재계산
                ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
                IXGuard* guard = CX_GET_OBJ(ctx, "guard", IXGuard);
                
                if(IS_VALID(priceMgr)) {
                    string symbol = sig.GetSymbol();
                    int dir = sig.GetDir();
                    double marketPrice = priceMgr.GetMarketPrice(symbol, dir);
                    sig.SetPriceOpen(marketPrice);
                    
                    double finalSL = priceMgr.CalculateSL(xp, symbol, dir, marketPrice, sig.GetSL());
                    double finalTP = priceMgr.CalculateTP(xp, symbol, dir, marketPrice, sig.GetTP());
                    
                    if(IS_VALID(guard)) {
                        double vBase = priceMgr.GetLiquidationPrice(symbol, dir);
                        if(finalSL > 0 && !guard.ValidateStopLevel(symbol, vBase, finalSL)) finalSL = 0;
                        if(finalTP > 0 && !guard.ValidateStopLevel(symbol, vBase, finalTP)) finalTP = 0;
                    }
                    sig.SetPriceSL(finalSL);
                    sig.SetPriceTP(finalTP);
                    
                    XP_LOG_INFO(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, 
                        StringFormat("Market Fallback Prices Recalculated. Mkt:%.5f, SL:%.5f, TP:%.5f", marketPrice, finalSL, finalTP)));
                }
                
                // [v1.3.1 Fix] Clear ticket and status to bypass OrderManager safety guard during Market Fallback
                sig.SetTicket(0);
                sig.SetStatus(XE_READY);
                
                if(orderMgr.ExecuteEntry(xp)) {
                    // [v16.26 Mandate] 포지션 진입 후 SID, Ticker 재맵핑
                    ulong newTicket = (ulong)sig.GetTicket();
                    sig.SetStatus(XE_EXECUTED);
                    sig.SetStatusMsg("Market Fallback Entered");
                    sig.SetTag("ENTRY_TE_REBOUND"); // [v1.0] 진입 경로 태깅

                    XP_LOG_OK(xp, CXAuditFormatter::Build("PEND-R-REMAP", xp, 
                        StringFormat("Market Fallback SUCCESS. Remapping Ticket: %I64u -> %I64u, Tag:ENTRY_TE_REBOUND", oldTicket, newTicket)));

                    if(IS_VALID(repo)) repo.UpdateStatus(sig);
                    
                    // [v1.2 Fix] 플래그 정리
                    ctx.Remove(reboundKey);
                    return SESSION_ACTIVE; // [v1.0 Fix] 확정 전이
                }
            }
            
            string lastErr = xp.GetString();
            if(lastErr == "") lastErr = "Market Fallback attempt failed";
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "FAILED: " + lastErr));
            xp.SetString("[PEND-R-APPLY] " + lastErr);
            return SESSION_ERROR;
        }


        double newPrice = xp.GetDouble();
        if(newPrice > 0) {
            XP_LOG_TRACE(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, StringFormat("Attempting Modify: %.5f", newPrice)));
            IXGuard* guard = CX_GET_OBJ(ctx, "guard", IXGuard);
            ICXPriceManager* priceMgr = CX_GET_OBJ(ctx, "price_mgr", ICXPriceManager);
            
            ICXSymbolManager* symMgr = CX_GET_OBJ(ctx, "sym_mgr", ICXSymbolManager);
            double point = IS_VALID(symMgr) ? symMgr.GetPoint(sig.GetSymbol()) : SymbolInfoDouble(sig.GetSymbol(), SYMBOL_POINT);
            int digits = IS_VALID(symMgr) ? symMgr.GetDigits(sig.GetSymbol()) : (int)SymbolInfoInteger(sig.GetSymbol(), SYMBOL_DIGITS);
            double dir_sign = (sig.GetDir() == CX_DIR_BUY) ? 1.0 : -1.0;
            double finalSL = sig.GetPriceSL();
            double finalTP = sig.GetPriceTP();

            if(finalSL <= 0 && sig.GetSL() > 0) {
                if(IS_VALID(priceMgr)) finalSL = priceMgr.CalculateSL(xp, sig.GetSymbol(), sig.GetDir(), newPrice, sig.GetSL());
                else finalSL = NormalizeDouble(newPrice - (sig.GetSL() * point * dir_sign), digits);
            }
            if(finalTP <= 0 && sig.GetTP() > 0) {
                if(IS_VALID(priceMgr)) finalTP = priceMgr.CalculateTP(xp, sig.GetSymbol(), sig.GetDir(), newPrice, sig.GetTP());
                else finalTP = NormalizeDouble(newPrice + (sig.GetTP() * point * dir_sign), digits);
            }

            if(IS_VALID(guard) && !guard.ValidateStopLevel(sig.GetSymbol(), newPrice, finalSL)) {
                string guardErr = StringFormat("StopLevel Violation. P:%.5f, SL:%.5f", newPrice, finalSL);
                XP_LOG_WARN(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "FAILED: " + guardErr));
                xp.SetString("[PEND-R-APPLY] " + guardErr);
                return TASK_BREAK;
            }

            // [v16.21 Anti-Jitter Mandate] [v11.11 >= Mandate Compliance]
            // 현재 실제 오더 가격(PriceOpen)과 새로운 타겟 가격의 차이가 TEStep 이상일 때만 브로커 요청 송신
            double currentOrderPrice = sig.GetPriceOpen();
            if(MathAbs(newPrice - currentOrderPrice) >= sig.GetTEStep() * point) {
                if(orderMgr.ModifyOrder(xp, (ulong)sig.GetTicket(), newPrice, finalSL, finalTP)) {
                    sig.UpdatePriceSignal(newPrice);
                    sig.SetSL(finalSL);
                    sig.SetTP(finalTP);
                    CXMessageProvider::UpdateStatus(sig, sig.GetStatus(), MSG_ENTRY_TRAILING_MODIFIED);
                    if(IS_VALID(repo)) repo.UpdateStatus(sig);
                    XP_LOG_OK(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, StringFormat("SUCCESS: Order Modified to %.5f", newPrice)));
                } else {
                    string modErr = StringFormat("Broker rejected price modification to %.5f", newPrice);
                    XP_LOG_ERROR(xp, CXAuditFormatter::Build("PEND-R-APPLY", xp, "FAILED: " + modErr));
                    xp.SetString("[PEND-R-APPLY] " + modErr);
                }
            } else {
                // 변화량이 너무 적으므로 수정 생략 (챠트 라인 떨림 방지)
                return TASK_CONTINUE;
            }
        }

        return TASK_CONTINUE;
    }
};

#endif
