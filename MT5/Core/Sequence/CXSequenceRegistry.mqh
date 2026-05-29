#ifndef CXSEQUENCEREGISTRY_MQH
#define CXSEQUENCEREGISTRY_MQH

#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayString.mqh>
#include "CXFluentSequence.mqh"
#include "CXSequenceStage.mqh"
#include "..\..\Workflow\Orchestration\CXStageFactory.mqh"

/**
 * @class CXSequenceRegistry
 * @brief [v16.6] CXSequenceStage 리스트를 기반으로 CXFluentSequence를 조립 (Enum-less)
 */
class CXSequenceRegistry {
public:
    static void BuildSequence(CXFluentSequence* seq, CArrayObj* map) {
        if(IS_INVALID(seq) || IS_INVALID(map)) return;

        for(int i = 0; i < map.Total(); i++) {
            CXSequenceStage* cfg = CX_CAST(CXSequenceStage, map.At(i));
            if(IS_INVALID(cfg)) continue;

            // [v16.6] StageFactory에 문자열 명칭을 직접 전달
            IXStage* stage = CXStageFactory::CreateStage(cfg.GetStageTypeStr(), cfg.GetName(), cfg.GetTasks());
            if(IS_VALID(stage)) {
                seq.From(cfg.GetStateId())
                   .Execute(stage)
                   .OnSuccess(cfg.GetNextId())
                   .OnFail(cfg.GetFailId())
                   .Timeout(cfg.GetTimeout())
                   .Retries(cfg.GetRetries());

                //--- [Branches] Case 분기 적용
                CHashMap<int, int>* branches = cfg.GetBranches();
                if(IS_VALID(branches)) {
                    int b_keys[]; int b_values[];
                    branches.CopyTo(b_keys, b_values);
                    for(int k = 0; k < ArraySize(b_keys); k++) {
                        seq.Case(b_keys[k], b_values[k]);
                    }
                }
            }
        }
        seq.Build();
    }
};

#endif
