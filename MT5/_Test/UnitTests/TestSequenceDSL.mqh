#ifndef TEST_SEQUENCE_DSL_MQH
#define TEST_SEQUENCE_DSL_MQH

#include "..\..\Core\Sequence\CXSequenceOrchestrator.mqh"
#include "..\..\Core\Sequence\CXFluentSequence.mqh"
#include "..\..\Core\Models\CXContext.mqh"
#include "..\..\Workflow\Orchestration\AppOrchestrator.mqh"

class TestSequenceDSL {
public:
    static bool Run() {
        Print("--- Running TestSequenceDSL ---");
        bool allPassed = true;
        
        AppOrchestrator orchestrator;
        CXContext ctx;
        CXFluentSequence seq(GetPointer(ctx), "TestSeq");

        // Test Case 1: Session Sequence Build from DSL
        orchestrator.BuildSessionSequence(GetPointer(seq));
        
        // In AGS Next-Gen structure:
        // ORD_TRACKING (1) + POS_MONITORING (2) + POS_TRAILING (3) + SESSION_LIQUIDATING (4) = 4 nodes
        if (seq.GetNodeCount() == 4) {
            Print("  [PASS] Session sequence built with 4 nodes.");
        } else {
            PrintFormat("  [FAIL] Expected 4 nodes, got %d", seq.GetNodeCount());
            allPassed = false;
        }

        // Test Case 2: Custom DSL Build (Modern Space/Terminator-based syntax)
        CArrayObj customMap;
        string customDsl[] = {
            "TestState > Composite:TestStep:TASK_E_L_VALIDATE ? NextState ! FailState @ 10s, 5x"
        };
        orchestrator.BuildFromDSL(customDsl, GetPointer(customMap));
        
        if (customMap.Total() == 1) {
            CXSequenceStage* step = CX_CAST(CXSequenceStage, customMap.At(0));
            int expectedStateId = orchestrator.ResolveId("TestState");
            if (step.GetStateId() == expectedStateId && step.GetName() == "TestStep" && step.GetTimeout() == 10 && step.GetRetries() == 5) {
                Print("  [PASS] Custom DSL parsed correctly.");
            } else {
                PrintFormat("  [FAIL] Custom DSL node data mismatch. Expected State:%d Name:TestStep Timeout:10 Retries:5. Got State:%d Name:%s Timeout:%d Retries:%d",
                            expectedStateId, step.GetStateId(), step.GetName(), step.GetTimeout(), step.GetRetries());
                allPassed = false;
            }
        } else {
            PrintFormat("  [FAIL] Expected 1 custom node, got %d", customMap.Total());
            allPassed = false;
        }

        return allPassed;
    }
};

#endif
