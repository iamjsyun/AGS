# DESIGN: AGS 테스트 프로젝트 구조 및 시뮬레이션 설계서 (v2.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.2 | 2026-05-30 | 초기 Dual-Zone 아키텍처 및 폴더 구조 정의 | System |
| v2.0 | 2026-05-31 | [Master Plan v1.0] 반영: 세분화된 클래스 기반의 계층적 테스트 설계 및 5+ Tick 시뮬레이션 표준 확립 | Antigravity |

---

## 1. 개요 (Overview)
본 설계서는 `PLAN_MASTER_IMPLEMENTATION_v1.0.md`에 의해 리팩토링된 AGS 엔진의 무결성을 검증하기 위한 포괄적 테스트 아키텍처를 정의합니다. 단순한 기능 확인을 넘어, 실제 트레이딩의 시계열(Time-series) 특성을 반영한 **5단계 이상의 Tick 시뮬레이션**을 통해 결정론적(Deterministic) 검증 환경을 구축합니다.

---

## 2. 테스트 계층 구조 (Test Layer Strategy)

### 2.1. Layer 1: 원자적 단위 테스트 (Atomic Unit Tests)
- **대상**: 리팩토링으로 추출된 4대 핵심 단위 클래스.
- **방식**: Mock 객체 주입을 통한 순수 로직(Pure Logic) 검증.
- **검증 항목**:
    - `CXHistoryAnalyzer`: Deal/Order 히스토리 데이터를 통한 청산 사유 판별 정확도.
    - `CXOrderValidator`: StopsLevel 및 Point 단위 가격 보정 수학 모델의 정밀도.
    - `CXRiskEvaluator`: 계좌 상태(Equity/Margin) 대비 주문 차단 임계치 작동 여부.
    - `CXPriceNormalizer`: 심볼별 TickSize 및 Digits 기반 반올림 오차 검증.

### 2.2. Layer 2: 단위 시나리오 테스트 (Component-Level Scenarios)
- **대상**: 개별 매니저(Order, Position, Exit)의 다중 틱 워크플로우.
- **방식**: TSDL 기반의 특정 기능 집중 시뮬레이션.
- **규모**: **3개 케이스 x 케이스당 5개 시나리오 (총 15개)**.

### 2.3. Layer 3: 통합 시나리오 테스트 (System-Level E2E)
- **대상**: 엔진 전체 (Watcher → OrderMgr → Session → ExitMgr).
- **방식**: 실제 시장 상황을 모사한 풀 라이프사이클 시뮬레이션.
- **규모**: **고정 3대 핵심 시나리오**.

---

## 3. 단위 시나리오 설계 (Unit Scenarios - 3 Cases)

각 시나리오는 최소 **5 Tick Step** 이상으로 구성되어 상태 전이의 안정성을 확인합니다.

### Case A: 진입 보정 및 거부 대응 (Entry & Validator)
1. **SCEN_ENTRY_NORMAL**: 표준 시장가 진입 및 티켓 바인딩.
2. **SCEN_ENTRY_STOPS_ADJ**: StopsLevel 위반 시 가격 자동 보정 후 진입.
3. **SCEN_ENTRY_RISK_REJECT**: 증거금 부족에 의한 리스크 매니저의 진입 차단.
4. **SCEN_ENTRY_BROKER_FAIL**: 브로커 서버 응답 없음(Timeout) 시 재시도 로직.
5. **SCEN_ENTRY_DUP_SID**: 동일 SID 신호 중복 주입 시 원자적 거부.

### Case B: 세션 관리 및 상태 동기화 (Session & Sync)
1. **SCEN_SYNC_VOLUME_DRIFT**: 터미널 내 부분 체결/수동 조절 시 볼륨 동기화.
2. **SCEN_SYNC_ZOMBIE_CLEAN**: 물리 자산은 없으나 DB에 남은 좀비 세션의 자동 제거.
3. **SCEN_SYNC_PENDING_TO_ACTIVE**: 대기 주문이 시장가 체결(Limit Fill)될 때의 세션 전이.
4. **SCEN_SYNC_STALE_PROTECT**: DB 통신 지연 시 터미널 데이터를 우선하는 Shadowing 검증.
5. **SCEN_SYNC_TRAILING_JITTER**: 급격한 틱 변동 시 트레일링 가격의 안정적 갱신.

### Case C: 청산 판별 및 복구 (Exit & Analyzer)
1. **SCEN_EXIT_SL_HIT**: 실제 SL 터치에 의한 청산 및 Analyzer의 `XE_CLOSED_SL` 판별.
2. **SCEN_EXIT_TP_HIT**: 실제 TP 터치에 의한 청산 및 `XE_CLOSED_TP` 판별.
3. **SCEN_EXIT_MANUAL**: 사용자의 터미널 수동 종료 감지 및 DB 즉시 마킹.
4. **SCEN_EXIT_PARTIAL_CLOSE**: 분할 청산 시 남은 잔량에 대한 세션 유지.
5. **SCEN_EXIT_RECOVERY**: 청산 처리 중 접속 끊김 후 재연결 시의 상태 완결성.

---

## 4. 통합 시나리오 설계 (Integrated Scenarios - 3 Total)

현실적인 트레이딩 상황을 10+ Tick 이상의 장기 시뮬레이션으로 설계합니다.

### S1. Golden Path (The Standard Profit)
- **구성**: 신호 감지 → 리스크 검증 → 주문 전송 → 체결 확인 → 트레일링 추적 → TP 청산 → 히스토리 완결.
- **목적**: 엔진의 모든 컴포넌트가 협력하여 정상 수익을 실현하는 표준 경로 검증.

### S2. Market Chaos (Broker Rejections & Manual Drifts)
- **구성**: 진입 시도(거부됨) → 재시도(성공) → 수동 SL 수정(감지) → 브로커 임의 청산 → Analyzer 사유 분석.
- **목적**: 외부 간섭 및 시장의 불확실성 속에서 데이터 정합성을 유지하는 복원력 검증.

### S3. Extreme Resilience (System Disconnect & Stale Recovery)
- **구성**: 세션 활성화 중 터미널 강제 종료 시뮬레이션 → 재구동 → Stale 데이터 감지 → 터미널 실물 스캔 → 세션 재바인딩.
- **목적**: 시스템 크래시나 재부팅 상황에서도 거래 자산을 잃지 않고 추적을 재개하는 능력 검증.

---

## 5. 시뮬레이션 타임라인 표준 (Tick Step Standard)

모든 시나리오는 현실성을 위해 다음 5단계를 기본 뼈대로 설계합니다.

| Tick | 단계 (Step) | 동작 (Action / Reality) | 검증 포인트 (Expectation) |
| :--- | :--- | :--- | :--- |
| **T1** | **Discovery** | DB 신호 주입 및 Watcher 감지 | `ICXSignal` 객체 생성 및 Context 바인딩 확인 |
| **T2** | **Validation** | Validator 및 RiskEvaluator 검사 | 가격 보정 결과 및 리스크 합격 유무 확인 |
| **T3** | **Execution** | Terminal로 주문 전송 시뮬레이션 | `XE_PENDING_REQ` 상태 및 브로커 리턴 코드 확인 |
| **T4** | **Binding** | 체결 데이터 수신 및 티켓 매핑 | `XE_EXECUTED` 상태 전이 및 볼륨 일치 확인 |
| **T5+** | **Management** | Trailing 작동 및 청산 발생 | 트레일링 가격 갱신 및 `XE_CLOSED_*` 사유 정확도 |

---

## 6. 결론 및 향후 계획
본 v2.0 설계를 기반으로 `Test/01_Scenarios/` 폴더 내에 18종(15+3)의 `.tsd` 시나리오 파일을 생성하고, 이를 `run_all_scenarios.ps1`을 통해 자동화 테스트 파이프라인에 통합함으로써 AGS 엔진의 무결성을 기계적으로 증명할 것입니다.
