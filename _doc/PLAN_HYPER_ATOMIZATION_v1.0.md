# PLAN: 하이퍼-아토마이제이션(Hyper-Atomization) 및 원자 단위 테스트 구현 계획서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 거대 클래스 분해 및 1:1 원자 단위 테스트(Atomic Unit Testing) 로드맵 수립 | Antigravity |

---

**Status**: Proposed  
**Author**: Antigravity  
**Target**: `MT5/03_Platform/` 하위 전 모듈 및 `MT5/99_TestFramework/UnitTests/Atomic/`  
**Reference**: [PLAN_MASTER_IMPLEMENTATION_v1.2.md](PLAN_MASTER_IMPLEMENTATION_v1.2.md)

---

## 1. 개요 (Overview)

본 계획서는 AGS 엔진의 유지보수성과 신뢰성을 극대화하기 위해 매니저 클래스를 최소 기능 단위인 **원자 부품(Atomic Components)**으로 분해하는 상세 구현 지침입니다. 각 부품은 MT5 시스템 API로부터 완전히 격리된 **Pure Logic**으로 작성되어, 밀리초(ms) 단위의 초고속 결정론적 테스트 환경을 제공합니다.

---

## 2. 클래스 분해 설계 (Atomic Decomposition Map)

| 기존 매니저 | 원자 단위 클래스 (Sub-components) | 역할 및 책임 |
| :--- | :--- | :--- |
| **CXTerminalPlatform** | **`CXHistoryNavigator`**<br>**`CXDealInterpreter`**<br>**`CXAccountMonitor`** | 히스토리 데이터 순회 관리<br>단일 Deal/Order 속성 해석 로직<br>계좌 지표(Equity/Margin) 정규화 |
| **CXOrderManager** | **`CXStopsGuard`**<br>**`CXOrderTransformer`** | 최소 거리(StopsLevel) 준수 여부 수학적 판정<br>엔진 모델을 MqlTradeRequest 구조체로 매핑 |
| **CXRiskManager** | **`CXLotStepAligner`**<br>**`CXMarginQuoter`** | 브로커 로트 스텝(0.01 등)에 따른 정밀 정렬<br>거래 방향/볼륨에 따른 요구 증거금 사전 산출 |
| **CXPriceManager** | **`CXTickScraper`**<br>**`CXPriceInverter`** | TickSize/Digits 기반 가격 반올림/절사 유틸리티<br>매수/매도 방향에 따른 가격 반전(Flip) 계산 |
| **AppOrchestrator** | **`CXGraphValidator`**<br>**`CXDslParser`** | 시퀀스 노드 간 순환 참조 및 연결성 검증<br>문자열 DSL의 문법 및 의미 해석 |

---

## 3. 디렉토리 구조 및 배치 표준 (Structure Standard)

### 3.1. 소스 코드 위치
*   **원자 클래스**: `MT5/03_Platform/Internal/[Category]/`
*   **인터페이스**: `MT5/01_Core/Interfaces/Internal/` (필요 시)

### 3.2. 테스트 코드 위치
*   **원자 단위 테스트**: `MT5/99_TestFramework/UnitTests/Atomic/`
*   **표준 명명 규칭**: `Test[AtomicClassName].mqh`

---

## 4. 원자 단위 테스트(Atomic Unit Testing) 가이드라인

1.  **Zero-Mock Dependency**: 원자 클래스는 다른 복잡한 매니저나 Mock을 주입받지 않고, 기본 데이터 타입(int, double, string)만으로 입력받아 결과를 반환해야 함.
2.  **Boundary Value Test**: 각 부품의 한계값(예: 로트 0.0, 가격 0.0, StopsLevel 0 등)에 대한 엣지 케이스 테스트를 반드시 포함.
3.  **Performance Priority**: 개별 테스트 실행 시간은 1ms를 초과하지 않아야 하며, 수백 개의 테스트가 동시에 실행되어도 지연이 없어야 함.

---

## 5. 단계별 실행 로드맵 (Phased Implementation)

### [Step 1] 인프라 및 가격 원자화 (즉각 실행)
- `CXTickScraper`, `CXPriceInverter` 구현 및 테스트.
- 가장 빈번히 호출되는 가격 정규화 로직의 안정성 확보.

### [Step 2] 리스크 및 주문 원자화
- `CXLotStepAligner`, `CXStopsGuard` 구현 및 테스트.
- 주문 거절(10015 에러)의 핵심 원인인 수학적 오차 원천 차단.

### [Step 3] 히스토리 해석 및 모니터 원자화
- `CXDealInterpreter`, `CXAccountMonitor` 구현 및 테스트.
- 브로커 청산 사유 판별 로직의 정교화.

### [Step 4] 매니저 재조립 (Manager Re-assembly)
- 분해된 원자 부품들을 컴포지션(Composition) 방식으로 기존 매니저에 적용.
- 기존 TSDL 시나리오를 통한 회귀 테스트(Regression Test) 수행.

---

## 6. 기대 효과
- **코드 중복 제거**: 공통 계산 로직이 원자 클래스로 집약되어 중복 코드 90% 이상 제거.
- **테스트 커버리지 100%**: 모든 비즈니스 규칙이 터미널 없이 기계적으로 검증됨.
- **시스템 기민성**: 소스 코드 한 줄 수정 시 수반되는 영향 범위를 원자 단위에서 즉각 파악.
