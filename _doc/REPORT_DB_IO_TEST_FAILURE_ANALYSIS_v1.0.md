# REPORT: DB I/O 단위 테스트 실패 분석 보고서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | DB I/O 테스트 실패 원인 분석 및 해결 방안 문서화 | Gemini CLI |

---

## 1. 개요 (Overview)
본 보고서는 AGS 엔진의 DB I/O 무결성 검증 과정에서 발생한 초기 테스트 실패 원인을 분석하고, 이를 해결하기 위해 적용된 기술적 조치 사항을 기록합니다.

---

## 2. 증상 (Symptoms)
- **현상**: 단위 테스트 실행 스크립트(`run_unit_tests.ps1`, `run_backtest_unit.ps1`) 실행 시, 터미널은 구동되나 결과 파일(`scenario_result.txt`)이 생성되지 않아 **타임아웃(Timeout)** 발생.
- **오류 메시지 (Logs)**: 
    - `MQL5 debugger symbol 'Gold#' is not found`
    - `Tester not started because terminal is not synchronized with the trade server`
    - `Experts expert AGSConnectivityTest not found from start config`

---

## 3. 원인 분석 (Root Cause Analysis)

### 3.1. 심볼 명칭 불일치 (Symbol Mismatch)
- **문제**: 브로커 서버(XM Global)마다 상이한 골드 심볼 명칭(`Gold#` vs `GOLD#`)으로 인해 터미널이 차트를 생성하지 못함.
- **결과**: 차트가 열리지 않아 해당 차트에 바인딩된 EA(`AGSConnectivityTest`)가 로드되지 않음.

### 3.2. 터미널 동기화 지연 및 동적 환경 부족
- **문제**: Strategy Tester가 구동되기 전 서버와의 계정 동기화가 완료되지 않아 테스트 실행이 거부됨.
- **결과**: 테스트 엔진이 시작조차 되지 않아 결과 파일 생성이 원천 차단됨.

### 3.3. 자동 매매 옵션 비활성화
- **문제**: 터미널 기본 설정에서 자동 매매(Auto-Trading)가 꺼져 있어, EA가 로드되더라도 `OnInit()` 이후의 동작이 제한됨.

### 3.4. 파일 경로 및 정크션(Junction) 부재
- **문제**: 터미널 데이터 폴더 내에 프로젝트 소스에 대한 심볼릭 링크(Junction)가 설정되지 않아 EA 파일을 찾지 못함.

---

## 4. 해결 방안 및 구현 사항 (Solutions)

### 4.1. 프로젝트 표준화 (Standardization)
- **심볼 통일**: 모든 설정과 코드에서 심볼 명칭을 대문자 **`GOLD#`**으로 강제함.
- **자격 증명 명문화**: 테스트용 계정 정보를 `GEMINI.md`에 표준으로 등록하여 일관성 확보.

### 4.2. 자가 치유형 DB 로직 (Self-Healing DB)
- **개선**: 기존의 템플릿 DB 복사 방식에서 탈피하여, 엔진(`CXDatabase`)이 직접 DB 유무를 판단하고 자동 생성(`DATABASE_OPEN_CREATE`) 및 스키마를 주입하도록 변경.
- **효과**: "Template database NOT found" 경고 원천 해결.

### 4.3. 실행 환경 강화 (Execution Hardening)
- **명령줄 옵션 추가**: 모든 실행 스크립트에 `/experts:on` 옵션을 추가하여 자동 매매 활성화 강제.
- **명시적 로그인**: `/config` 파일 외에 `/login`, `/password`, `/server` 옵션을 명령줄에 직접 전달하여 동기화 신뢰도 향상.
- **Login Preservation**: 사용자의 기존 환경을 보호하기 위해 테스트 전후 `config` 폴더 백업/원복 로직 구현.

### 4.4. 환경 자동 구축 (Auto Setup)
- **Junction Setup**: `setup_mt5_junction.ps1`을 통해 터미널 데이터 폴더와 프로젝트 폴더를 자동으로 연결.

---

## 5. 최종 결과 (Final Outcome)
- **백테스트 모드**: `run_unit_backtest.ps1` 실행 결과 **성공 (PASSED)**.
- **라이브 모드**: `run_unit_live.ps1` 실행 결과 **성공 (PASSED)**.
- **검증 완료**: DB 생성, 테이블 초기화, 신호 쓰기 및 읽기 라이프사이클 전체가 정상 작동함을 확인.

---

## 6. 결론
초기 실패는 주로 **환경 설정의 불일치**와 **터미널 구동 특성**에 대한 대응 부족에서 기인했습니다. 이번 분석을 통해 구축된 **이중 모드 테스트 실행 전략**은 향후 AGS 엔진 개발 및 검증의 견고한 기반이 될 것입니다.
