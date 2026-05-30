//+------------------------------------------------------------------+
//|                                            TestPVBIntegrity.mqh  |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Pre-Validated Binding (PVB) 전수 무결성 단위 테스트       |
//|                                                                  |
//| 목적: 모든 서비스 의존성 태스크가 Bind()를 올바르게 구현하였는지, |
//|       서비스 누락 시 Fail-Fast가 정상 동작하는지를 검증한다.     |
//+------------------------------------------------------------------+
#ifndef TEST_PVB_INTEGRITY_MQH
#define TEST_PVB_INTEGRITY_MQH

//--- Active Tasks
#include "..\\..\\Workflow\\Tasks\\Active\\CXTaskSync_V_Stale.mqh"
#include "..\\..\\Workflow\\Tasks\\Active\\CXTaskActive_V_Terminal.mqh"
#include "..\\..\\Workflow\\Tasks\\Active\\CXTaskActive_P_Align.mqh"
#include "..\\..\\Workflow\\Tasks\\Active\\CXTaskIntentWatch.mqh"
//--- Exit Tasks (Service-Dependent)
#include "..\\..\\Workflow\\Tasks\\Exit\\CXTaskExit_P_Finalize.mqh"
#include "..\\..\\Workflow\\Tasks\\Exit\\CXTaskExit_P_Lock.mqh"
#include "..\\..\\Workflow\\Tasks\\Exit\\CXTaskExit_R_Order.mqh"
#include "..\\..\\Workflow\\Tasks\\Exit\\CXTaskExit_V_Terminal.mqh"
//--- Exit Tasks (Pure — No Service Dependency)
#include "..\\..\\Workflow\\Tasks\\Exit\\CXTaskExit_L_Prepare.mqh"
#include "..\\..\\Workflow\\Tasks\\Exit\\CXTaskExit_V_Error.mqh"
//--- Pending Task
#include "..\\..\\Workflow\\Tasks\\Pending\\CXTaskPending_V_Sync.mqh"
//--- Trailing Tasks
#include "..\\..\\Workflow\\Tasks\\Trailing\\CXTaskTrail_V_Activate.mqh"
#include "..\\..\\Workflow\\Tasks\\Trailing\\CXTaskTrail_V_Extremum.mqh"
#include "..\\..\\Workflow\\Tasks\\Trailing\\CXTaskTrail_L_Evaluate.mqh"
#include "..\\..\\Workflow\\Tasks\\Trailing\\CXTaskTrail_R_Execute.mqh"
//--- Core
#include "..\\..\\Core\\Models\\CXContext.mqh"
#include "..\\..\\Core\\Models\\CXParam.mqh"
#include "..\\..\\Core\\Models\\CXSignal.mqh"
//--- Mocks
#include "..\\Mocks\\MockRepository.mqh"
#include "..\\Mocks\\MockAssetManager.mqh"
#include "..\\Mocks\\MockPositionManager.mqh"
#include "..\\Mocks\\MockPriceManager.mqh"
#include "..\\Mocks\\MockTerminalPlatform.mqh"
#include "..\\Mocks\\MockOrderManager.mqh"
#include "..\\Mocks\\MockExitManager.mqh"
#include "..\\Mocks\\MockSymbolManager.mqh"

/**
 * @class TestPVBIntegrity
 * @brief Pre-Validated Binding 전수 검증 단위 테스트
 *
 * [섹션 구조]
 *   Part 1 — Full Context: 전체 Mock 서비스 등록 후 13개 태스크 Bind() 전수 검사
 *   Part 2 — Pure Tasks:   서비스 없는 컨텍스트에서 Pure Task Bind() + Execute() 검사
 *   Part 3 — Fail-Fast:    서비스 일부 미등록 시 Bind() 실패 여부 검사
 */
class TestPVBIntegrity {
private:
    /**
     * @brief 전체 Mock 서비스를 컨텍스트에 등록
     */
    static void BuildFullContext(CXContext &ctx,
                                 MockRepository &repo,
                                 MockAssetManager &assetMgr,
                                 MockPositionManager &posMgr,
                                 MockPriceManager &priceMgr,
                                 MockTerminalPlatform &terminal,
                                 MockOrderManager &orderMgr,
                                 MockExitManager &exitMgr,
                                 MockSymbolManager &symMgr) {
        ctx.Register("repo",               GetPointer(repo));
        ctx.Register("asset_mgr",          GetPointer(assetMgr));
        ctx.Register("pos_mgr",            GetPointer(posMgr));
        ctx.Register("price_mgr",          GetPointer(priceMgr));
        ctx.Register("terminal_platform",  GetPointer(terminal));
        ctx.Register("order_mgr",          GetPointer(orderMgr));
        ctx.Register("exit_mgr",           GetPointer(exitMgr));
        ctx.Register("sym_mgr",            GetPointer(symMgr));
    }

    /**
     * @brief Bind() 결과를 기대값과 비교하고 결과를 출력
     */
    static bool AssertBind(string taskName, bool actual, bool expected, bool &allPassed) {
        if(actual == expected) {
            PrintFormat("    [PASS] %-42s Bind()=%s", taskName + ":", actual ? "true " : "false");
        } else {
            PrintFormat("    [FAIL] %-42s Expected=%s, Got=%s", taskName + ":",
                        expected ? "true" : "false", actual ? "true" : "false");
            allPassed = false;
        }
        return (actual == expected);
    }

public:
    static bool Run() {
        Print("--- Running TestPVBIntegrity (Pre-Validated Binding Integrity Check) ---");
        bool allPassed = true;

        // ================================================================
        // Part 1: Full Context — 전체 서비스 등록 시 모든 Bind() 성공 검증
        // ================================================================
        Print("  [PART 1] Full Context — 13 Service-Dependent Tasks Must Bind Successfully");
        {
            CXContext            ctx;
            MockRepository       repo;
            MockAssetManager     assetMgr;
            MockPositionManager  posMgr;
            MockTerminalPlatform terminal;
            MockPriceManager     priceMgr(GetPointer(ctx));
            MockOrderManager     orderMgr;
            MockExitManager      exitMgr(GetPointer(terminal));
            MockSymbolManager    symMgr;
            BuildFullContext(ctx, repo, assetMgr, posMgr, priceMgr, terminal, orderMgr, exitMgr, symMgr);

            // --- Active Tasks (4개) ---
            CXTaskSync_V_Stale      t_stale;
            CXTaskActive_V_Terminal t_actTerm;
            CXTaskActive_P_Align    t_align;
            CXTaskIntentWatch       t_intentWatch;

            AssertBind("CXTaskSync_V_Stale",      t_stale.Bind(GetPointer(ctx)),       true, allPassed);
            AssertBind("CXTaskActive_V_Terminal",  t_actTerm.Bind(GetPointer(ctx)),     true, allPassed);
            AssertBind("CXTaskActive_P_Align",     t_align.Bind(GetPointer(ctx)),       true, allPassed);
            AssertBind("CXTaskIntentWatch",        t_intentWatch.Bind(GetPointer(ctx)), true, allPassed);

            // --- Exit Tasks — Service-Dependent (4개) ---
            CXTaskExit_P_Finalize t_finalize;
            CXTaskExit_P_Lock     t_lock;
            CXTaskExit_R_Order    t_order;
            CXTaskExit_V_Terminal t_exitTerm;

            AssertBind("CXTaskExit_P_Finalize",    t_finalize.Bind(GetPointer(ctx)),  true, allPassed);
            AssertBind("CXTaskExit_P_Lock",        t_lock.Bind(GetPointer(ctx)),      true, allPassed);
            AssertBind("CXTaskExit_R_Order",       t_order.Bind(GetPointer(ctx)),     true, allPassed);
            AssertBind("CXTaskExit_V_Terminal",    t_exitTerm.Bind(GetPointer(ctx)),  true, allPassed);

            // --- Pending Task (1개) ---
            CXTaskPending_V_Sync t_pending;
            AssertBind("CXTaskPending_V_Sync",     t_pending.Bind(GetPointer(ctx)),   true, allPassed);

            // --- Trailing Tasks (4개, TE/TS 각 2쌍) ---
            CXTaskTrail_V_Activate t_teActivate(TRAIL_MODE_ENTRY);
            CXTaskTrail_V_Activate t_tsActivate(TRAIL_MODE_EXIT);
            CXTaskTrail_V_Extremum t_teExtremum(TRAIL_MODE_ENTRY);
            CXTaskTrail_V_Extremum t_tsExtremum(TRAIL_MODE_EXIT);
            CXTaskTrail_L_Evaluate t_teEval(TRAIL_MODE_ENTRY);
            CXTaskTrail_L_Evaluate t_tsEval(TRAIL_MODE_EXIT);
            CXTaskTrail_R_Execute  t_teExec(TRAIL_MODE_ENTRY);
            CXTaskTrail_R_Execute  t_tsExec(TRAIL_MODE_EXIT);

            AssertBind("CXTaskTrail_V_Activate(TE)", t_teActivate.Bind(GetPointer(ctx)), true, allPassed);
            AssertBind("CXTaskTrail_V_Activate(TS)", t_tsActivate.Bind(GetPointer(ctx)), true, allPassed);
            AssertBind("CXTaskTrail_V_Extremum(TE)", t_teExtremum.Bind(GetPointer(ctx)), true, allPassed);
            AssertBind("CXTaskTrail_V_Extremum(TS)", t_tsExtremum.Bind(GetPointer(ctx)), true, allPassed);
            AssertBind("CXTaskTrail_L_Evaluate(TE)", t_teEval.Bind(GetPointer(ctx)),     true, allPassed);
            AssertBind("CXTaskTrail_L_Evaluate(TS)", t_tsEval.Bind(GetPointer(ctx)),     true, allPassed);
            AssertBind("CXTaskTrail_R_Execute(TE)",  t_teExec.Bind(GetPointer(ctx)),     true, allPassed);
            AssertBind("CXTaskTrail_R_Execute(TS)",  t_tsExec.Bind(GetPointer(ctx)),     true, allPassed);
        }

        // ================================================================
        // Part 2: Pure Tasks — 서비스 없는 컨텍스트에서도 정상 동작 검증
        // ================================================================
        Print("  [PART 2] Pure Tasks (Exit_L_Prepare, Exit_V_Error) — No Service Dependency");
        {
            CXContext emptyCtx; // 어떤 서비스도 등록하지 않음

            CXTaskExit_L_Prepare t_lPrepare;
            CXTaskExit_V_Error   t_vError;

            // Pure Task는 기본 IXTask::Bind()를 상속하여 항상 true 반환
            AssertBind("CXTaskExit_L_Prepare (Pure)", t_lPrepare.Bind(GetPointer(emptyCtx)), true, allPassed);
            AssertBind("CXTaskExit_V_Error (Pure)",   t_vError.Bind(GetPointer(emptyCtx)),   true, allPassed);

            // Pure Task의 Execute() 기본 동작 검증
            CXParam xp;
            CXSignal sig;
            sig.SetSid("PVB-PURE-01");
            sig.SetXAExit(XA_ACTIVE);   // 청산 요청 상태
            sig.SetStatus(XE_EXECUTED); // 정상 실행 중
            xp.SetSignal(GetPointer(sig));

            int resLPrepare = t_lPrepare.Execute(GetPointer(xp), GetPointer(emptyCtx));
            if(resLPrepare == TASK_CONTINUE) {
                Print("    [PASS] CXTaskExit_L_Prepare: Execute returned TASK_CONTINUE for XA_ACTIVE intent.");
            } else {
                PrintFormat("    [FAIL] CXTaskExit_L_Prepare: Expected TASK_CONTINUE, got %d.", resLPrepare);
                allPassed = false;
            }

            // Exit_V_Error: 타임아웃 없는 상태에서는 TASK_CONTINUE 반환 검증
            CXParam xpErr;
            CXSignal sigErr;
            sigErr.SetSid("PVB-PURE-02");
            sigErr.SetXAExit(XA_ACTIVE);
            sigErr.SetStatus(XE_EXECUTED);
            xpErr.SetSignal(GetPointer(sigErr));

            int resVError = t_vError.Execute(GetPointer(xpErr), GetPointer(emptyCtx));
            if(resVError == TASK_CONTINUE) {
                Print("    [PASS] CXTaskExit_V_Error: Execute returned TASK_CONTINUE before timeout.");
            } else {
                PrintFormat("    [FAIL] CXTaskExit_V_Error: Expected TASK_CONTINUE, got %d.", resVError);
                allPassed = false;
            }
        }

        // ================================================================
        // Part 3: Fail-Fast Guard — 서비스 일부 누락 시 Bind() 실패 검증
        // ================================================================
        Print("  [PART 3] Fail-Fast Guard — Missing Services Must Cause Bind() Failure");
        {
            // 부분 컨텍스트: repo만 등록, 나머지 서비스 없음
            CXContext partialCtx;
            MockRepository repo;
            partialCtx.Register("repo", GetPointer(repo));

            // --- CXTaskActive_P_Align: pos_mgr 누락 시 false 반환 기대 ---
            CXTaskActive_P_Align t_align;
            bool bindAlign = t_align.Bind(GetPointer(partialCtx));
            if(!bindAlign) {
                Print("    [PASS] Fail-Fast: CXTaskActive_P_Align failed Bind() due to missing 'pos_mgr'. ✓");
            } else {
                Print("    [FAIL] Fail-Fast: CXTaskActive_P_Align returned true despite missing 'pos_mgr'.");
                allPassed = false;
            }

            // --- CXTaskTrail_V_Activate(TS): price_mgr 누락 시 false 반환 기대 ---
            CXTaskTrail_V_Activate t_tsActivate(TRAIL_MODE_EXIT);
            bool bindTrail = t_tsActivate.Bind(GetPointer(partialCtx));
            if(!bindTrail) {
                Print("    [PASS] Fail-Fast: CXTaskTrail_V_Activate(TS) failed Bind() due to missing 'price_mgr'. ✓");
            } else {
                Print("    [FAIL] Fail-Fast: CXTaskTrail_V_Activate(TS) returned true despite missing 'price_mgr'.");
                allPassed = false;
            }

            // --- CXTaskExit_R_Order: exit_mgr, asset_mgr 누락 시 false 반환 기대 ---
            CXTaskExit_R_Order t_order;
            bool bindOrder = t_order.Bind(GetPointer(partialCtx));
            if(!bindOrder) {
                Print("    [PASS] Fail-Fast: CXTaskExit_R_Order failed Bind() due to missing 'exit_mgr'. ✓");
            } else {
                Print("    [FAIL] Fail-Fast: CXTaskExit_R_Order returned true despite missing 'exit_mgr'.");
                allPassed = false;
            }

            // --- CXTaskPending_V_Sync: asset_mgr 누락 시 false 반환 기대 ---
            CXTaskPending_V_Sync t_pending;
            bool bindPending = t_pending.Bind(GetPointer(partialCtx));
            if(!bindPending) {
                Print("    [PASS] Fail-Fast: CXTaskPending_V_Sync failed Bind() due to missing 'asset_mgr'. ✓");
            } else {
                Print("    [FAIL] Fail-Fast: CXTaskPending_V_Sync returned true despite missing 'asset_mgr'.");
                allPassed = false;
            }

            // --- 완전 빈 컨텍스트: 모든 서비스 의존 태스크 실패 검증 ---
            CXContext emptyCtx;
            CXTaskActive_V_Terminal t_actTerm;
            bool bindActTerm = t_actTerm.Bind(GetPointer(emptyCtx));
            if(!bindActTerm) {
                Print("    [PASS] Fail-Fast: CXTaskActive_V_Terminal failed Bind() on empty context. ✓");
            } else {
                Print("    [FAIL] Fail-Fast: CXTaskActive_V_Terminal returned true on empty context.");
                allPassed = false;
            }
        }

        if(allPassed) {
            Print("  [RESULT] TestPVBIntegrity: ALL PASSED — PVB 패턴 무결성 확인 완료.");
        } else {
            Print("  [RESULT] TestPVBIntegrity: FAILED — PVB 패턴 위반 태스크 존재.");
        }

        return allPassed;
    }
};

#endif // TEST_PVB_INTEGRITY_MQH
