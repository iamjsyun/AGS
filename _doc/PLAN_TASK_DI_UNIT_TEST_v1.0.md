# PLAN: AGS DI 단위 테스트(PVB) 구현 및 고도화 계획서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | Pre-Validated Binding (PVB) 기반 DI 단위 테스트 구현 초기 로드맵 수립 | Antigravity |

---

**Status**: Proposed  
**Author**: Antigravity  
**Target**: `MT5/99_TestFramework/UnitTests/` 및 `MT5/05_Guard/`  
**Reference**: [DESIGN_PRE_VALIDATED_BINDING_v2.0.md](file:///D:/projects/ags/_doc/DESIGN_PRE_VALIDATED_BINDING_v2.0.md) 및 [GEMINI.md](file:///D:/projects/ags/GEMINI.md)

---

## 1. 개요 (Overview)

본 계획서는 AGS 엔진의 핵심 제어 흐름인 **Stage, Sequence, Task**에 대한 **의존성 주입(Dependency Injection, DI) 단위 테스트**를 구현하기 위한 로드맵입니다. 런타임 중 발생할 수 있는 '서비스 누락(Missing Service)' 크래시를 원천 차단하기 위해 **Pre-Validated Binding (PVB)** 방식을 사용하여 실행 전 모든 구성 요소의 정합성을 100% 검증합니다.

---

## 2. 단위 테스트 설계 전략 (Test Strategy)

`TestPVBIntegrity.mqh` 클래스를 기반으로 다음 3단계 검증 파이프라인을 확립합니다.

### 2.1. Part 1: Full Context Verification (Positive Test)
*   **목표**: 엔진 내 등록된 모든 Task가 필요로 하는 서비스가 완벽히 주입되었을 때 정상적으로 바인딩을 완료하는지 검증.
*   **구현 방법**:
    1.  `MockTerminalPlatform`, `MockAssetManager` 등 모든 의존성 서비스의 Mock 객체를 생성.
    2.  `CXContext`에 위 8개 핵심 서비스를 모두 등록 (`BuildFullContext` 헬퍼 함수 활용).
    3.  현재 존재하는 13종의 Task 인스턴스를 생성 후, 각각 `Bind(ctx)` 호출 결과가 `true`인지 `AssertBind`로 확인.

### 2.2. Part 2: Pure Task Verification (No Dependency)
*   **목표**: 외부 서비스 의존성이 없는 순수(Pure) Task들이 빈(Empty) 컨텍스트 환경에서도 정상 동작하는지 검증.
*   **구현 방법**:
    1.  아무 서비스도 등록하지 않은 빈 `CXContext` 생성.
    2.  `CXTaskExit_L_Prepare`, `CXTaskExit_V_Error` 등 시스템 서비스 없이 동작하는 Task를 주입.
    3.  `Bind()` 통과 및 가상 상태(예: `XA_ACTIVE`) 주입 시 `Execute()`가 `TASK_CONTINUE`를 반환하는지 검증.

### 2.3. Part 3: Fail-Fast Guard Verification (Negative Test)
*   **목표**: 런타임 환경 결함 등으로 특정 서비스가 누락되었을 때, Task가 즉각적으로 오류를 보고하며 바인딩에 실패(Fail-Fast)하는지 엄격히 검증.
*   **구현 방법**:
    1.  일부 서비스만 의도적으로 누락시킨 `Partial Context` 생성 (예: `pos_mgr` 제외).
    2.  누락된 서비스를 필수로 요구하는 Task(`CXTaskActive_P_Align`)에 `Bind()` 실행.
    3.  반환값이 **반드시 `false`**인지 확인하고, 정상 처리 시 테스트 실패로 간주.

---

## 3. 고도화 및 확장 구현 계획 (Phase 2 & 3)

기본 PVB 단위 테스트 완료 후, 인프라의 자동화 수준을 높이기 위해 다음 확장 기능을 구현합니다.

### 3.1. Composite Stage 및 Sequence 스캔 (Phase 2)
개별 Task 검증을 넘어 묶음 단위의 바인딩을 테스트합니다.
*   `CXStageFactory::CreateCompositeStage`로 다중 Task가 포함된 Stage 생성.
*   Stage의 `Bind()` 호출 한 번으로, 내부의 모든 Task가 연쇄적으로(Recursive) 바인딩 및 Fail-Fast 로직을 전파하는지 단위 테스트 내에서 검증.

### 3.2. Automated DI Scan 및 순환 참조 방어 (Phase 3)
*   `CXIntegrityGuard` 내부 로직을 강화하여, 부트스트랩 시 `AppOrchestrator`가 생성한 거대한 Sequence Graph를 순회하며 의존성 트리를 구축.
*   태스크-서비스 간, 혹은 서비스 간의 순환 의존성(Circular Dependency)이 발생할 경우, 부팅 단계에서 즉시 `FATAL` 오류를 로깅하고 EA를 종료하는 방어 로직 추가.

---

## 4. 실행 로드맵 및 기대 효과 (Roadmap & Expected Outcomes)

### 4.1. Implementation Roadmap
1.  **Phase 1 (즉각 실행)**: `MT5/99_TestFramework/UnitTests/TestPVBIntegrity.mqh` 코드 최적화 및 `run_unit_tests.ps1` 파이프라인 정규 편입.
2.  **Phase 2**: `TestSequenceDSL.mqh` 내에 Composite Stage 바인딩 검증 케이스 추가.
3.  **Phase 3**: `CXIntegrityGuard.mqh` 고도화를 통한 부트스트랩 DI 스캔 로직 탑재.

### 4.2. Expected Outcomes
*   **Runtime Crash 제로화**: 컴파일 타임에 잡을 수 없는 런타임 의존성 누락 에러(`error 199`, Null Pointer Exception)를 테스트 단계에서 원천 봉쇄.
*   **유지보수 안정성**: 새로운 Task나 Service를 추가할 때 잊지 않고 의존성을 등록하도록 강제하는 '안전망' 확보.
*   **TDD/BDD 인프라 강화**: 인프라 변경에 대한 두려움 없이 비즈니스 로직 수정이 가능.
