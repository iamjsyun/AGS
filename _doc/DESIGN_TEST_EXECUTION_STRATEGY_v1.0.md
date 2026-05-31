# DESIGN: AGS 테스트 실행 전략 (Live vs. Backtest) (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 테스트 실행 모드(Live, Backtest)의 완전한 분리 및 계층화 설계 | Gemini CLI |

---

## 1. 개요 (Overview)
본 문서는 AGS 엔진의 신뢰성을 검증하기 위한 두 가지 테스트 실행 모드를 정의합니다. **라이브 트레이딩 모드**와 **백테스트(Strategy Tester) 모드**의 목적, 설정 및 안전 수칙을 명확히 함으로써, 개발 환경의 일관성을 유지하고 사용자의 기존 환경을 보호하는 것을 목적으로 합니다.

---

## 2. 테스트 모드 정의 (Execution Modes)

### 2.1. 라이브 트레이딩 모드 (Live Mode)
- **정의**: 실제 MT5 터미널 인스턴스를 구동하여 브로커 서버와 실시간으로 통신하며 테스트를 수행.
- **용도**: 네트워크 지연, 서버 응답 코드, 실시간 틱 처리 등 현실적인 트레이딩 환경 검증.
- **필수 수칙**:
    - **Login Preservation**: 테스트 전 사용자의 기존 로그인 정보를 백업하고, 테스트 완료 후 즉시 원복.
    - **Auto-Trading**: 터미널 실행 시 `/experts:on` 옵션 필수 적용.
- **설정**: `Test/02_Config/unit_live.ini`, `scenario_live.ini`

### 2.2. 백테스트 모드 (Backtest Mode)
- **정의**: MT5 Strategy Tester 엔진 내에서 가상의 시간을 기반으로 테스트를 수행.
- **용도**: 결정론적(Deterministic) 로직 검증, 대량의 시나리오 고속 처리, DB 무결성 테스트.
- **장점**: 네트워크 상태에 영향을 받지 않으며 실행 속도가 매우 빠름.
- **설정**: `Test/02_Config/unit_backtest.ini`, `scenario_backtest.ini`

---

## 3. 테스트 표준 규격 (Standard Compliance)

모든 테스트는 다음의 공통 표준을 준수합니다.

| 항목 | 표준값 | 비고 |
| :--- | :--- | :--- |
| **기본 심볼** | `GOLD#` | 모든 테스트 및 개발의 표준 종목 |
| **테스트 ID** | `315136196` | XM Global 데모 계정 |
| **테스트 Pass** | `xmDemo@2025` | 갱신된 테스트 자격 증명 |
| **데이터베이스** | `AGS.db` / `TestUnit.db` | 엔진에 의한 자가 치유(Auto-Create) 적용 |

---

## 4. 자동화 스크립트 구조 (Automation Infrastructure)

`Automation/Runners/` 폴더 내의 스크립트들은 목적에 따라 엄격히 구분됩니다.

### 4.1. 단위 테스트 (Unit Tests)
- `run_unit_live.ps1`: 라이브 환경에서 `AGSTestRunner.mq5` 실행.
- `run_unit_backtest.ps1`: 백테스트 환경에서 `AGSTestRunner.mq5` 실행.

### 4.2. 시나리오 테스트 (Scenario Tests)
- `run_scenario_live.ps1`: 라이브 환경에서 TSDL 시나리오 일괄 실행.
- `run_scenario_backtest.ps1`: 백테스트 환경에서 TSDL 시나리오 일괄 실행.

---

## 5. 안전 수칙: 로그인 정보 보호 (Login Preservation)
라이브 모드 테스트 실행 시, `Automation/Runners/run_unit_live.ps1` 또는 `run_scenario_live.ps1`은 다음 절차를 수행합니다.
1. 터미널의 `config/` 폴더를 임시 디렉토리에 백업.
2. 테스트용 계정으로 로그인 및 테스트 수행.
3. 테스트 종료 후 백업된 `config/` 데이터를 원래 위치로 복사하여 사용자의 기존 로그인을 복구.

---

## 6. 결론
이러한 이중 모드 실행 전략을 통해 AGS 프로젝트는 **현실적인 환경에서의 실구동 검증**과 **격리된 환경에서의 고속 로직 검증**을 동시에 달성하며, 개발자의 업무 효율성과 시스템의 안정성을 동시에 확보합니다.
