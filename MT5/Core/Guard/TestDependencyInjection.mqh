#ifndef TEST_DEPENDENCY_INJECTION_MQH
#define TEST_DEPENDENCY_INJECTION_MQH

#include "..\Interfaces\ICXContext.mqh"
#include "..\Macros\CXMacros.mqh"
#include "..\Sequence\CXSequenceOrchestrator.mqh"

/**
 * @class TestDependencyInjection
 * @brief EA 기동 시 컨텍스트 내의 서비스 의존성 주입 정합성을 최종 검증
 */
class TestDependencyInjection {
public:
    static bool Verify(ICXContext* ctx) {
        if(IS_INVALID(ctx)) {
            Print("[FATAL-DI] Verification failed: Context is NULL.");
            return false;
        }

        string requirements[] = {"repo", "asset_mgr", "price_mgr", "sym_mgr", "risk_mgr", "terminal_platform"};
        bool allValid = true;
        
        Print("==================================================");
        Print("Starting Dependency Injection Verification...");
        Print("==================================================");

        for(int i = 0; i < ArraySize(requirements); i++) {
            CObject* obj = ctx.Get(requirements[i]);
            if(IS_INVALID(obj)) {
                PrintFormat("  [FAIL] Service '%s' is missing or NULL in context.", requirements[i]);
                allValid = false;
            } else {
                PrintFormat("  [PASS] Service '%s' is registered and valid.", requirements[i]);
            }
        }

        // [v2.0] 시퀀스 오케스트레이터 바인딩 검증 (PVB Fail-Fast)
        if(allValid) {
            CXSequenceOrchestrator* orchestrator = CX_GET_OBJ(ctx, "orchestrator", CXSequenceOrchestrator);
            if(IS_INVALID(orchestrator)) {
                Print("  [FAIL] Orchestrator is missing in context.");
                allValid = false;
            } else {
                if(!orchestrator.Bind(ctx)) {
                    Print("  [FAIL] Sequence/Task Pre-Validated Binding (PVB) failed.");
                    allValid = false;
                } else {
                    Print("  [PASS] Sequence/Task Pre-Validated Binding (PVB) success.");
                }
            }
        }

        Print("==================================================");
        if(allValid) {
            Print("Dependency Injection Verification SUCCESS.");
        } else {
            Print("Dependency Injection Verification FAILED.");
        }
        Print("==================================================");

        return allValid;
    }
};

#endif
