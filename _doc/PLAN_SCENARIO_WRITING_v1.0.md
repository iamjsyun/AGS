# PLAN: TSDL 고정밀 시나리오(18종) 구현 계획서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | [DESIGN_TEST_PROJECT_STRUCTURE_v2.0.md] 기반 18종 시나리오 파일 제작 로드맵 수립 | Antigravity |

---

**Status**: Proposed  
**Author**: Antigravity  
**Target**: `Test/01_Scenarios/` 하위 전 폴더  
**Reference**: [DESIGN_TEST_PROJECT_STRUCTURE_v2.0.md](file:///D:/projects/ags/_doc/DESIGN_TEST_PROJECT_STRUCTURE_v2.0.md)

---

## 1. 개요 (Overview)

본 계획서는 `DESIGN_TEST_PROJECT_STRUCTURE_v2.0.md`에서 설계된 15개의 단위 시나리오와 3개의 통합 시나리오, 총 **18개의 `.tsd` 파일**을 실제 구현하기 위한 작업 지침입니다. 모든 시나리오는 실제 트레이딩의 시계열적 흐름을 반영하여 최소 5단계(Tick) 이상의 시뮬레이션으로 구성됩니다.

---

## 2. 구현 대상 및 파일 목록 (Writing Targets)

### 2.1. Case A: 진입 및 검증 (Entry & Validator) - 5개
*   `Test/01_Scenarios/Core/test_entry_normal_v2.tsd`
*   `Test/01_Scenarios/Core/test_entry_stops_adj_v2.tsd` ([완료])
*   `Test/01_Scenarios/Core/test_entry_risk_reject_v2.tsd`
*   `Test/01_Scenarios/Core/test_entry_broker_fail_v2.tsd`
*   `Test/01_Scenarios/Core/test_entry_dup_sid_v2.tsd`

### 2.2. Case B: 세션 및 동기화 (Session & Sync) - 5개
*   `Test/01_Scenarios/Resilience/test_sync_volume_drift_v2.tsd`
*   `Test/01_Scenarios/Resilience/test_sync_zombie_clean_v2.tsd` ([완료])
*   `Test/01_Scenarios/Resilience/test_sync_pending_to_active_v2.tsd`
*   `Test/01_Scenarios/Resilience/test_sync_stale_protect_v2.tsd`
*   `Test/01_Scenarios/Resilience/test_sync_trailing_jitter_v2.tsd`

### 2.3. Case C: 청산 및 판별 (Exit & Analyzer) - 5개
*   `Test/01_Scenarios/Trade/test_exit_sl_hit_v2.tsd`
*   `Test/01_Scenarios/Trade/test_exit_tp_hit_v2.tsd`
*   `Test/01_Scenarios/Trade/test_exit_manual_v2.tsd`
*   `Test/01_Scenarios/Trade/test_exit_partial_close_v2.tsd`
*   `Test/01_Scenarios/Trade/test_exit_recovery_v2.tsd`

### 2.4. 통합 시나리오 (Integrated E2E) - 3개
*   `Test/01_Scenarios/Trade/test_integrated_golden_path_v2.tsd` ([완료])
*   `Test/01_Scenarios/Trade/test_integrated_market_chaos_v2.tsd`
*   `Test/01_Scenarios/Trade/test_integrated_extreme_resilience_v2.tsd`

---

## 3. 시나리오 작성 표준 규격 (Simulation Standards)

1.  **Tick Sequence**: 각 시나리오는 `TICK: 1`부터 최소 `TICK: 5`까지 명시적 단계를 가짐.
2.  **Mock Integration**:
    *   `INJECT: signals`: DB 상태 강제 주입.
    *   `INJECT: terminal`: 브로커 물리 상태(Order/Position/History) 강제 주입.
3.  **Strict Expectation**:
    *   `EXPECT: session`: 엔진 내부 상태(`ORD_READY`, `POS_ACTIVE` 등) 검증.
    *   `EXPECT: signal`: DB 저장 상태(`xe_status`, `xa_exit` 등) 검증.
4.  **Reality Check**: `MARKET: [SYMBOL]` 명령을 통해 가상 가격 이동을 시뮬레이션하여 트레일링 및 SL/TP 작동 유도.

---

## 4. 단계별 구현 및 검증 로드맵 (Roadmap)

### [Phase 1] 파일 생성 및 컨텐츠 작성
- 각 카테고리별로 `.tsd` 파일을 순차적으로 작성합니다.
- 복잡도가 낮은 단위 시나리오(Case A)부터 시작하여 통합 시나리오로 확장합니다.

### [Phase 2] 매니페스트(Manifest) 등록 및 동기화
- `Test/01_Scenarios/scenario_manifest.json` 파일에 신규 생성된 시나리오들을 등록합니다.

### [Phase 3] 자동화 실행 및 결과 검증
- `run_all_scenarios.ps1`을 실행하여 18종의 시나리오가 모두 **PASSED** 되는지 확인합니다.
- 실패 시, 리팩토링된 원자 클래스의 로직을 수정하거나 시나리오의 기댓값(Expectation)을 보정합니다.

---

## 5. 기대 효과
- **회귀 테스트 완결성**: 엔진의 모든 기능 변경에 대해 기계적으로 무결성을 증명할 수 있는 '완전한 방어막' 구축.
- **문서화 대체**: 시나리오 파일 자체가 엔진의 작동 방식을 설명하는 살아있는 명세서(Living Documentation) 역할을 수행.
