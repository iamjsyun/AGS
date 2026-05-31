# PLAN: 테스트 프레임워크 현대화 및 표준화 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 분석 보고서(v1.0) 기반 프레임워크 고도화 및 전수 수정 계획 수립 | Gemini CLI |

---

## 1. 배경 및 목적
`REPORT_DB_IO_TEST_FAILURE_ANALYSIS_v1.0.md` 분석 결과, 기존 테스트 프레임워크의 환경 의존성과 설정 불일치(심볼 명칭 등)가 주요 실패 원인으로 파악되었습니다. 이를 해결하기 위해 테스트 코드, 프레임워크 엔진, 자동화 스크립트를 통합적으로 현대화하고 표준화하는 작업을 수행합니다.

---

## 2. 주요 수정 작업 항목

### 2.1. 심볼 명칭 전수 표준화 (Symbol Normalization)
- **대상**: `.mqh`, `.mq5`, `.tsd`, `.ini`, `.md` 모든 파일.
- **작업**: 기존의 혼용된 심볼 명칭(`Gold#`, `EURUSD` 등)을 프로젝트 표준인 **`GOLD#`**으로 일괄 치환.
- **목적**: 브로커 서버와의 동기화 오류(`symbol not found`) 원천 차단.

### 2.2. 자가 치유형 DB 패턴 확산 (Self-Healing DB)
- **프레임워크**: `CXDatabase::Open`의 `DATABASE_OPEN_CREATE` 로직을 모든 단위 테스트 클래스에 적용.
- **스크립트**: 구형 스크립트에 남아있는 `ats.db` 존재 여부 확인 및 수동 복사 로직 제거.
- **목적**: 외부 의존성(파일 존재) 없는 Zero-Config 테스트 환경 구축.

### 2.3. 자동화 스크립트 구조 재편 (Runner Consolidation)
- **신규 도입**: 이중 모드(Live vs. Backtest) 실행 스크립트 4종 확정 및 고도화.
    - `run_unit_live.ps1` / `run_unit_backtest.ps1`
    - `run_scenario_live.ps1` / `run_scenario_backtest.ps1`
- **폐기 대상**: 혼선을 유발하는 구형/임시 스크립트 제거.
    - `run_unit_tests.ps1`, `run_connectivity_test.ps1`, `run_all_scenarios.ps1` 등.
- **강화**: 모든 실행 명령에 `/experts:on` 및 명시적 로그인 옵션(`Login/Pass/Server`) 필수 포함.

### 2.4. 로그인 정보 보호 자동화 (Login Preservation)
- **구현**: 라이브 모드 실행 시 `config/` 폴더 자동 백업 및 테스트 종료 후 자동 원복 로직을 모든 라이브 러너에 표준 탑재.

---

## 3. 실행 단계 (Implementation Steps)

### Phase 1: 기반 인프라 정리 (Batch Update)
1.  프로젝트 전체에서 `Gold#` -> `GOLD#` 일괄 치환 (Subagent 활용).
2.  구형 테스트 스크립트 및 임시 INI 파일 물리적 삭제.
3.  `GEMINI.md` 표준 준수 여부 재검증.

### Phase 2: 단위 테스트 코드 고도화
1.  `MT5/99_TestFramework/UnitTests/` 내의 모든 테스트 파일 검수.
2.  DB 연동이 필요한 테스트에서 `TestDbIo`에서 증명된 `Open("TestUnit.db", false)` 패턴 적용.

### Phase 3: 최종 통합 검증
1.  `run_unit_backtest.ps1` 실행 (전체 Pass 확인).
2.  `run_unit_live.ps1` 실행 (전체 Pass 및 로그인 정보 원복 확인).
3.  `run_scenario_backtest.ps1` 실행 (TSDL 시나리오 15종 연동 확인).

---

## 4. 기대 효과
- **신뢰성**: 환경 차이에 따른 "False Negative" 테스트 실패 제거.
- **안전성**: 자동화 테스트 중 개발자의 실제 계정 정보 및 설정 유실 방지.
- **효율성**: 원클릭으로 모든 환경(백테스트/라이브)에서 즉시 검증 가능.
