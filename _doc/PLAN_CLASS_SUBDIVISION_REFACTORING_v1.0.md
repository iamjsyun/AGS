# PLAN: 단위 테스트 고도화를 위한 클래스 세분화(Subdivision) 및 리팩토링 계획서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 단위 테스트 효율성 극대화를 위한 거대 클래스 세분화 대상 식별 및 설계 청사진 수립 | Antigravity |

---

**Status**: Proposed  
**Author**: Antigravity  
**Target**: `MT5/03_Platform/` 하위 핵심 실행 모듈들  
**Reference**: [GEMINI.md](file:///D:/projects/ags/GEMINI.md) 내 Engineering Standards 및 단위 테스트 규격

---

## 1. 개요 (Overview)

본 계획서는 AGS 엔진 내 기능이 집중된 거대 클래스(Monolithic Classes)들을 단일 책임 원칙(SRP)에 따라 원자적(Atomic) 기능 단위로 세분화하는 리팩토링 로드맵입니다. 핵심 비즈니스 계산 및 판별 로직을 물리적 통신 계층에서 분리하여, **Mock 데이터 기반의 빠르고 결정론적인 단위 테스트(Unit Testing)** 환경을 구축하는 것을 목적으로 합니다.

---

## 2. 세분화 대상 클래스 및 분할 설계 (Refactoring Blueprint)

| 대상 클래스 (Current) | 핵심 분할 로직 | 신규 단위 클래스 (New) | 단위 테스트 이점 |
| :--- | :--- | :--- | :--- |
| **`CXTerminalPlatform`** | MT5 히스토리 루프 탐색 및 청산 사유 분석 (`CheckHistoryClosure`) | **`CXHistoryAnalyzer`** | 라이브 터미널 연결 없이, 미리 정의된 Mock Deal/Order 데이터를 주입하여 SL/TP/수동 청산 판별 로직을 100% 독립 검증 가능. |
| **`CXOrderManager`** | StopsLevel 기반 브로커 거부 방지 및 가격 보정 알고리즘 | **`CXOrderValidator`** | 주문을 실제로 전송하지 않고도, 다양한 심볼과 극단적 시장가 상황에서 가격 보정 수학 로직의 정확성을 검증 가능. |
| **`CXRiskManager`** | 최대 로트, 마진콜 방어 등 리스크 정책 및 실시간 산출 | **`CXRiskEvaluator`** | 가상의 계좌 상태(Equity 부족 등)를 주입하여 엔진이 위험 상태를 올바르게 감지하고 주문을 차단하는지 안전하게 테스트. |
| **`CXPriceManager`** | TickSize, Digits 기반 가격 정규화(Normalization) | **`CXPriceNormalizer`** | 통화쌍(예: JPY) 및 금속 등 각기 다른 자릿수 환경에서 발생하는 반올림/내림 오차를 빠르고 포괄적으로 테스트. |

---

## 3. 구현 전략 (Implementation Guidelines)

1.  **위임(Delegation) 및 의존성 주입**:
    - 기존 매니저 클래스(예: `CXTerminalPlatform`)는 인터페이스를 유지하여 기존 시스템에 영향을 주지 않는 파사드(Facade) 역할로 남깁니다.
    - 실제 로직은 새로 추출된 `CXHistoryAnalyzer` 등의 단위 클래스로 위임하며, 이들은 `ICXContext`를 통해 상호 의존성을 주입받도록 합니다.
2.  **순수 함수(Pure Function) 지향**:
    - 분할된 클래스의 주요 판별 및 계산 함수는 내부 상태를 가지지 않고(Stateless), 입력값에 대해서만 의존하는 순수 함수 형태로 작성하여 부작용(Side-effect)을 최소화합니다.
3.  **병행 테스트 개발 (TDD Approach)**:
    - 리팩토링 시, 클래스 분할 작업과 함께 해당 클래스를 검증하는 전용 `UnitTests/` 스위트를 동시에 작성합니다.

---

## 4. 실행 로드맵 (Execution Roadmap)

*   **Phase 1**: `CXTerminalPlatform` 로직 분할 (`CXHistoryAnalyzer` 추출 및 단위 테스트 작성)
*   **Phase 2**: `CXOrderManager` 로직 분할 (`CXOrderValidator` 추출 및 단위 테스트 작성)
*   **Phase 3**: `CXPriceManager` 및 `CXRiskManager` 산출 로직 분리
*   **Phase 4**: 분할된 모든 클래스가 기존 통합 테스트(TSDL 시나리오)를 통과하는지 최종 검증

---

## 5. 기대 효과
- **테스트 커버리지 향상**: 물리 환경에서 재현하기 힘든 예외 케이스를 Mock을 통해 쉽게 만들어 테스트 가능.
- **코드 복잡도 감소**: 파일당 코드 라인 수를 줄이고 책임 소재를 명확히 하여 유지보수 및 디버깅 효율성 증대.
