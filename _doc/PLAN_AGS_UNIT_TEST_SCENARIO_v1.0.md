# PLAN: AGS Unit Test Scenario Test Plan (v1.0)

## Document History
| Version | Date       | Author     | Description                                         |
| :------ | :--------- | :--------- | :-------------------------------------------------- |
| v1.0    | 2026-05-31 | Gemini CLI | Initial creation of unit test scenario test plan. |

## 1. 개요 (Introduction)
본 문서는 AGS(Anti-Gravity System)의 핵심 로직 및 컴포넌트의 무결성을 검증하기 위한 단위 테스트 시나리오 및 실행 계획을 정의한다. AGS는 복잡한 트레이딩 상태 머신을 다루므로, 각 모듈의 독립적인 동작 확인과 상호 의존성(Dependency Injection)의 올바른 바인딩 여부를 검증하는 것이 필수적이다.

## 2. 테스트 환경 및 인프라 (Test Environment & Infrastructure)

### 2.1 자동화 스크립트 (Automation Scripts)
- **경로**: `Automation/Runners/run_unit_tests.ps1`
- **역할**: 
  - MT5 터미널 종료 및 환경 정리.
  - 테스트 전용 데이터베이스(`AGS.db`) 초기화.
  - 유닛 테스트 전용 EA(`AGSTestRunner.mq5`) 가동 지시.
  - 결과 파일(`scenario_result.txt`) 폴링 및 최종 성공/실패 판정.

### 2.2 테스트 러너 (Test Runner EA)
- **경로**: `MT5/99_TestFramework/AGSTestRunner.mq5`
- **방식**: `OnInit()` 단계에서 등록된 모든 테스트 스위트(Suite)를 순차적으로 실행하고 결과를 파일로 기록 후 자가 종료.

### 2.3 모의 객체 (Mock Objects)
- **경로**: `MT5/99_TestFramework/Mocks/`
- **역할**: 터미널 플랫폼, 레포지토리, 가격 관리자 등을 가상화하여 외부 환경(브로커 연결 등) 없이 로직을 독립적으로 검증.

## 3. 테스트 전략 (Test Strategy)

### 3.1 하이퍼 아토믹 테스트 (Hyper-Atomization Tests)
- 상태가 없는 순수 로직 함수(Pure Functions)를 대상으로 한다.
- 가격 변환, 로트 보정, 경계값 검사 등 수학적 정확성이 중요한 모듈이 대상이다.

### 3.2 통합 및 매니저 테스트 (Integration & Manager Tests)
- `ICXContext`를 통한 의존성 주입(DI)이 정상적으로 이루어지는지 검증한다.
- 시그널 상태 전이, 터미널 자산 바인딩, 트레일링 로직 등 상태 머신 기반의 복합 로직을 검증한다.

### 3.3 PVB(Pre-Validated Binding) 무결성 검증
- 모든 Task가 실행 전 필요한 서비스를 정상적으로 참조(`Bind()`)하는지 확인한다.
- 서비스 누락 시 Fail-Fast 메커니즘이 동작하여 예기치 않은 크래시를 방지하는지 검증한다.

## 4. 테스트 시나리오 카탈로그 (Test Scenario Catalog)

### 4.1 Atomic Pure-Logic Suites
| 스위트명 | 대상 모듈 | 주요 검증 내용 |
| :--- | :--- | :--- |
| `TestTickScraper` | `CXTickScraper` | 틱 데이터 수집 및 윈도우 관리 로직. |
| `TestPriceInverter` | `CXPriceInverter` | 매수/매도 방향에 따른 가격 반전 계산 정확도. |
| `TestLotStepAligner` | `CXLotStepAligner` | 브로커의 로트 스텝에 따른 정규화 및 최소/최대 로트 제한. |
| `TestStopsGuard` | `CXStopsGuard` | `StopsLevel`을 고려한 SL/TP 유효성 검사. |

### 4.2 Integration & Manager Suites
| 스위트명 | 대상 모듈 | 주요 검증 내용 |
| :--- | :--- | :--- |
| `TestEntryValidate` | `CXEntryManager` | 터미널 실물 자산과 DB 시그널 간의 PVB 바인딩 및 티켓 매칭. |
| `TestPVBIntegrity` | `CXTask` (All) | 13종 이상의 Task가 Full Context에서 정상적으로 Bind() 되는지 확인. |
| `TestExitWorkflow` | `CXExitManager` | 다단계 청산 프로세스(Lock -> Order -> Finalize) 흐름 검증. |
| `TestTrailingEntry` | `CXTaskTrail_L_Evaluate` | 진입 가격 추적 및 트리거 조건 만족 시 실행 명령 전달. |
| `TestTrailingStop` | `CXTaskTrail_R_Execute` | 시장 가격 변동에 따른 SL 수정 요청 생성 및 로깅. |
| `TestPendingSync` | `CXTaskPending_V_Sync` | 대기 시그널의 터미널 상태 동기화 및 만료 처리. |
| `TestActiveSync` | `CXTaskActive_V_Terminal` | 활성 포지션의 실시간 존재 여부 확인 및 수동 종료 감지. |
| `TestIntentWatch` | `CXTaskIntentWatch` | 사용자 의도(수동 조작 등) 감지 및 시스템 대응 로직. |

## 5. 실행 및 결과 확인 (Execution & Reporting)

### 5.1 테스트 실행 방법
PowerShell 터미널에서 다음 명령을 실행한다:
```powershell
powershell -File Automation/Runners/run_unit_tests.ps1
```

### 5.2 결과 판정 기준
1. **Console Output**: PowerShell 창에 "Unit tests successfully completed" 메시지 확인.
2. **Result File**: `MQL5/Files/AGS/scenario_result.txt` 내 `status=PASSED` 확인.
3. **Experts Log**: MT5 Experts 탭에서 `[PASS]` 프리픽스로 출력되는 상세 로그 검토.

### 5.3 실패 시 대응 절차
1. `Experts` 로그에서 실패한 테스트 스위트와 상세 `[FAIL]` 메시지 확인.
2. 해당 테스트 코드(`.mqh`) 내의 `Test Case` 번호와 Assert 조건을 분석.
3. 관련 도메인 로직 또는 Mock 데이터 주입 로직 수정 후 재테스트.
