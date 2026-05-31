#ifndef TEST_SMART_PVB_MQH
#define TEST_SMART_PVB_MQH

#include "..\..\02_Domain\Models\CXContext.mqh"
#include "..\..\06_Orchestration\Workflow\CXTaskFactory.mqh"
#include "..\Mocks\MockRepository.mqh"
#include "..\Mocks\MockAssetManager.mqh"
#include "..\Mocks\MockPositionManager.mqh"
#include "..\Mocks\MockPriceManager.mqh"
#include "..\Mocks\MockTerminalPlatform.mqh"
#include "..\Mocks\MockOrderManager.mqh"
#include "..\Mocks\MockExitManager.mqh"
#include "..\Mocks\MockSymbolManager.mqh"

/**
 * @class TestSmartPVB
 * @brief [v2.2] 자동 태스크 스캔 및 서비스 계약(Contract) 기반 의존성 무결성 테스트
 */
class TestSmartPVB {
private:
    static void BuildFullContext(CXContext &ctx, MockRepository &repo, MockAssetManager &assetMgr, MockPositionManager &posMgr, MockPriceManager &priceMgr, MockTerminalPlatform &terminal, MockOrderManager &orderMgr, MockExitManager &exitMgr, MockSymbolManager &symMgr) {
        ctx.Register("repo", &repo); ctx.Register("asset_mgr", &assetMgr); ctx.Register("pos_mgr", &posMgr); ctx.Register("price_mgr", &priceMgr);
        ctx.Register("terminal_platform", &terminal); ctx.Register("order_mgr", &orderMgr); ctx.Register("exit_mgr", &exitMgr); ctx.Register("sym_mgr", &symMgr);
    }

    static void BuildPartialContext(CXContext &ctx, string skipKey, MockRepository &repo, MockAssetManager &assetMgr, MockPositionManager &posMgr, MockPriceManager &priceMgr, MockTerminalPlatform &terminal, MockOrderManager &orderMgr, MockExitManager &exitMgr, MockSymbolManager &symMgr) {
        if(skipKey != "repo") ctx.Register("repo", &repo);
        if(skipKey != "asset_mgr") ctx.Register("asset_mgr", &assetMgr);
        if(skipKey != "pos_mgr") ctx.Register("pos_mgr", &posMgr);
        if(skipKey != "price_mgr") ctx.Register("price_mgr", &priceMgr);
        if(skipKey != "terminal_platform") ctx.Register("terminal_platform", &terminal);
        if(skipKey != "order_mgr") ctx.Register("order_mgr", &orderMgr);
        if(skipKey != "exit_mgr") ctx.Register("exit_mgr", &exitMgr);
        if(skipKey != "sym_mgr") ctx.Register("sym_mgr", &symMgr);
    }

public:
    static bool Run() {
        Print("--- Running TestSmartPVB (Automated Task Dependency Audit) ---");
        bool allPassed = true;

        CArrayString taskNames;
        CXTaskFactory::GetAvailableTasks(taskNames);

        for(int i = 0; i < taskNames.Total(); i++) {
            string name = taskNames.At(i);
            IXTask* task = CXTaskFactory::CreateTask(name);
            if(IS_INVALID(task)) { PrintFormat("  [FAIL] Could not create task: %s", name); allPassed = false; continue; }

            string reqs = task.GetRequiredServices();
            PrintFormat("  Auditing Task: %-25s (Reqs: %s)", name, reqs);

            // 1. Positive Test: Full Context
            CXContext fullCtx;
            MockRepository repo; MockAssetManager assetMgr; MockPositionManager posMgr; MockTerminalPlatform terminal;
            MockPriceManager priceMgr(&fullCtx); MockOrderManager orderMgr; MockExitManager exitMgr(&terminal); MockSymbolManager symMgr;
            BuildFullContext(fullCtx, repo, assetMgr, posMgr, priceMgr, terminal, orderMgr, exitMgr, symMgr);

            if(!task.Bind(&fullCtx)) {
                PrintFormat("    [FAIL] %s: Bind() failed in Full Context.", name);
                allPassed = false;
            }

            // 2. Negative Test: Permutation Fail-Fast
            string keys[];
            ushort sep = StringGetCharacter(",", 0);
            string tempReqs = reqs; StringReplace(tempReqs, " ", "");
            int keyCount = StringSplit(tempReqs, sep, keys);

            for(int k = 0; k < keyCount; k++) {
                string skip = keys[k];
                if(skip == "") continue;

                CXContext partialCtx;
                BuildPartialContext(partialCtx, skip, repo, assetMgr, posMgr, priceMgr, terminal, orderMgr, exitMgr, symMgr);
                
                if(task.Bind(&partialCtx)) {
                    PrintFormat("    [FAIL] %s: Bind() succeeded despite missing service: %s", name, skip);
                    allPassed = false;
                }
            }
            delete task;
        }

        if(allPassed) Print("--- TestSmartPVB: ALL PASSED ---");
        else Print("--- TestSmartPVB: SOME TESTS FAILED ---");

        return allPassed;
    }
};

#endif
