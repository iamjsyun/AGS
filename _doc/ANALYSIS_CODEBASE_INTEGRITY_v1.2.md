# ANALYSIS: AGS Codebase Integrity & Redundancy (v1.2)

## 1. 개요 (Overview)
본 문서는 AGS 시스템의 무결성 검증 체계 및 실행 로직에 대한 분석 보고서입니다. 시스템 시작부터 태스크 실행까지의 흐름을 추적하여 의존성 주입(DI) 가드의 중복성과 논리적 오류 위험 요소를 식별하였으며, 최신화된 프로젝트 구조를 포함합니다.

## 2. 프로젝트 구조 (Project Structure)
현재 AGS 프로젝트는 `DESIGN_AGS_UNIFIED_STRUCTURE_v1.2` 표준에 따라 다음과 같이 구성되어 있습니다.

```text
D:\PROJECTS\AGS
|   GEMINI.md
|
+---Automation
|   +---Build
|   |       build_ags.ps1
|   |       ...
|   +---Runners
|   |       run_unit_tests.ps1
|   |       ...
|   \---Tools
|           inspect_db.py
|           inspect_db_201.py
|
+---MT5
|   +---01_Core (System Infrastructure)
|   +---02_Domain (Logic & Models)
|   +---03_Platform (Terminal Bridge)
|   +---04_AppBootstrap (DI & Startup)
|   +---05_Guard (Security & Integrity)
|   +---06_Orchestration (Assembly)
|   +---07_Flow (Execution Flow)
|   \---99_TestFramework (Verification)
|
+---Test
|   +---01_Scenarios
|   +---02_Config
|   \---03_Results
|
+---_doc (Design & Analysis)
\---_log (System Logs)
```

## 3. 정량적 지표 (Quantitative Metrics)
| 항목 | 값 |
| :--- | :--- |
| 총 소스 파일 수 (*.mq5/*.mqh) | 52 |
| DI 검증 호출 수 (Refactor 후) | 1 (CXIntegrityGuard 단일 검증) |
| 레지스트리 내 필수 서비스 식별자 수 | 14 |
| 단위 테스트 커버리지 (DI 관련) | TestPVBIntegrity 및 12개 테스트 스위트 |

## 4. DI 흐름 및 검증 구조 (DI Flow Diagram - v1.2)
시스템의 의존성 주입 및 통합 검증 흐름은 다음과 같습니다.

```mermaid
flowchart TD
    subgraph Context["ICXContext (Global Service Registry)"]
        config["config"]
        logger["logger"]
        orchestrator["orchestrator"]
        guard["guard"]
        db["db"]
        repo["repo"]
        asset_mgr["asset_mgr"]
        price_mgr["price_mgr"]
        sym_mgr["sym_mgr"]
        risk_mgr["risk_mgr"]
        exit_mgr["exit_mgr"]
        terminal_platform["terminal_platform"]
        order_mgr["order_mgr"]
        pos_mgr["pos_mgr"]
    end
    
    AGS["AGS.mq5 OnInit()"]
    envGuard["CXIntegrityGuard::AuditEnvironment(InpDatabaseName)"]
    Initialize["CXAppService::Initialize()"]
    Inspect["CXIntegrityGuard::Inspect()"]
    
    InitSuccess["INIT_SUCCEEDED"]
    InitFail["INIT_FAILED"]

    AGS -->|1. Pre-Flight Environment Audit| envGuard
    envGuard -->|Success| AGS
    envGuard -->|Failure| InitFail
    
    AGS -->|2. Create Services & Bind| Initialize
    Initialize -->|3. Registry Check & Recursive Bind| Inspect
    Inspect -.->|Check Services in Context| Context
    Inspect -->|Success| Initialize
    Inspect -->|Failure - Log [EXEC-ENTRY-FAIL]| InitFail
    
    Initialize -->|4. Startup Success| AGS
    AGS --> InitSuccess
```

## 5. 분석 결과 (Findings)

### 5.1. 다중 레이어 DI 가드 중복 (DI Guard Redundancy)
현재 시스템은 `OnInit()` 단계에서 4중 검증 레이어를 거치고 있으며, 특히 다음 두 지점에서 심각한 중복이 확인되었습니다.
- **Redundancy A**: `CXIntegrityGuard::Inspect()`와 `TestDependencyInjection::Verify()`가 동일한 서비스 포인터 체크 및 오케스트레이터 바인딩(`Bind()`)을 반복 수행함.
- **Redundancy B**: `CXCompositeStage::AssertDependencies()`가 매 틱 실행 시마다 서비스 존재를 재확인함. 이는 `Bind()` 시점에 이미 검증된 항목들로 런타임 오버헤드를 유발함.

### 5.2. 실행 로직 분석 (Execution Logic)
- **TASK_YIELD 재시작 정책**: `CXCompositeStage`는 Yield 이후 재개 시 **Index 0 (IntentWatch)** 태스크를 항상 재실행함. 이는 우선순위 감시를 위한 의도된 설계이나, 특정 상황에서 불필요한 반복 계산의 원인이 될 수 있음.
- **Atomic Batch Delete**: `CXAssetManager`는 루프 안정성을 위해 세션 순회와 삭제 프로세스를 격리하여 설계 표준을 준수하고 있음.

## 6. 개선 제안 (Recommendations)

| 구분 | 조치 사항 | 기대 효과 |
| :--- | :--- | :--- |
| **통합** | `TestDependencyInjection`을 `CXIntegrityGuard`로 통합 및 제거 | `OnInit` 부하 감소 및 코드 슬림화 |
| **최적화** | `CXCompositeStage::AssertDependencies()` 제거 | 매 틱 발생하는 불필요한 조건 검사 제거 |
| **고도화** | Task Yield 재개 시 Task 0 실행 여부를 결정하는 플래그 도입 | 런타임 성능 및 논리적 유연성 확보 |

## 7. 결론
AGS v2.2 아키텍처는 매우 높은 수준의 복원력을 갖추고 있으나, 시스템 부트스트랩 단계의 중복 검증 로직을 정문화(Rationalization)함으로써 실행 효율성을 더욱 극대화할 수 있습니다.

---

## 8. v1.2 개선 작업 반영 및 검증 결과 (Refactor Implementation & Verification)
2026-05-30 개선 제안에 따라 리팩토링이 성공적으로 완료되었으며, 결과는 다음과 같습니다.

### 8.1. 조치 결과 (Implementation details)
1. **통합 (Integration - TestDependencyInjection 제거 및 통합)**:
   - `MT5/05_Guard/TestDependencyInjection.mqh` 파일을 프로젝트에서 삭제하였습니다.
   - `AGS.mq5` 메인 진입점에서 `TestDependencyInjection::Verify` 호출을 완전히 제거하였습니다.
   - 의존성 주입(DI) 검증 책임을 `CXIntegrityGuard` 서비스로 단일화하였으며, `CXIntegrityGuard::Inspect()` 실행 시 기존 `TestDependencyInjection`이 출력하던 형식의 상세 로그를 남기도록 개선하였습니다. 오류 발생 시에는 Trading Logging Standard를 준수하여 `[EXEC-ENTRY-FAIL]` 프리픽스를 출력하도록 정립하였습니다.
2. **최적화 (Optimization - AssertDependencies 제거)**:
   - `CXCompositeStage::AssertDependencies()`의 매 틱 실행 조건 검사를 제거하였습니다.
   - 대신 해당 필수 의존성 검증 로직은 조립 시점(`Bind()`)으로 이동시켜 런타임 오버헤드를 원천 차단하였습니다.
3. **고도화 (Advanced - Task 0 실행 제어 플래그 도입)**:
   - `CXCompositeStage`에 `m_skipTaskZeroOnYield` 플래그 및 `SetSkipTaskZeroOnYield(bool skip)` 빌더 메서드를 도입하였습니다.
   - 이를 통해 Task Yield 발생 후 재개 시, 우선순위 감시 태스크(Index 0 - IntentWatch)의 중복 실행 여부를 유연하게 제어할 수 있는 구조적 기틀을 확보하였습니다.

### 8.2. 검증 결과 (Verification Results)
- **빌드 테스트**: `build_ags.ps1` 및 `build_tests.ps1`을 통한 컴파일이 오류 및 경고 없이 성공(0 errors, 0 warnings)하였습니다.
- **단위 테스트**: `run_unit_tests.ps1`을 실행한 결과, `TestPVBIntegrity`를 포함한 12개 테스트 스위트가 모두 성공(12 PASSED, 0 FAILED)하였습니다.
  - `status=PASSED`
  - `TestPVBIntegrity=OK`
  - `TestIntegritySimulation=OK`
  - `TestActiveSync=OK`
  - 기타 모든 테스트 통과 완료.
