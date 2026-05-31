# REVIEW: Pre-Validated Binding (PVB) 설계 검토서 (v1.0)

**Status**: Active  
**Author**: Antigravity  
**Target Document**: [DESIGN_PRE_VALIDATED_BINDING_v2.0.md](file:///d:/Projects/AGS/_doc/DESIGN_PRE_VALIDATED_BINDING_v2.0.md)  
**Reference**: [GEMINI.md](file:///d:/Projects/AGS/GEMINI.md)

---

## 1. 검토 개요

본 검토서는 `DESIGN_PRE_VALIDATED_BINDING_v2.0.md` 문서의 설계 정합성, MQL5 플랫폼 제약사항 준수 여부, 그리고 프로젝트의 기본 규칙([GEMINI.md](file:///d:/Projects/AGS/GEMINI.md)) 준수 여부를 검토하고 개선 방향을 제안합니다.

---

## 2. 검토 결과 및 분석

### 2.1. 설계 정합성 및 패턴 분석 (Soundness of Design)
- **"Bind-then-Trust" 원칙의 타당성**:
  - MQL5 환경에서 동적 해시맵 조회(`CXContext::Get`) 및 런타임 캐스팅은 CPU 오버헤드를 발생시킵니다. `Bind()` 시점에 의존성 포인터를 private 멤버 변수에 캐싱하고 런타임에 직접 접근하는 방식은 연산 비용을 획기적으로 줄여주므로 **매우 타당한 설계**입니다.
  - 런타임 중 `NULL` 포인터 참조로 인한 터미널 크래시(EA 강제 종료)를 예방하기 위해, 기동(OnInit) 시점에 검증을 완결하는 Fail-Fast 모델은 거래 안정성 관점에서 필수적입니다.

### 2.2. [GEMINI.md] 규칙 준수 검토
- **문서 이력(Document History) 누락**:
  - [GEMINI.md](file:///d:/Projects/AGS/GEMINI.md)의 규칙인 *"모든 아티팩트는 문서 상단 또는 하단에 'Document History' 섹션을 포함하여, 이전 버전에서 변경된 핵심 사항과 이력을 파일 내부에서 즉시 확인할 수 있도록 해야 한다"*를 준수하지 않았습니다.
  - 현재 문서 상단에 메타데이터 형식으로 `Prev Version: v1.0`만 표시되어 있을 뿐, 구체적인 변경 이력 테이블이 누락되어 있습니다.

### 2.3. 아키텍처 중복성 검토 (2-Layer Verification Redundancy)
- **`CXIntegrityGuard`와 `TestDependencyInjection`**:
  - **계층 1 (`CXIntegrityGuard`)**: `AppService.Initialize()` 내부에서 실행되며 14개 전역 서비스 확인, 오케스트레이터 재귀 `Bind()`, 이중 해제(Double Free) 감사, 단일 데이터베이스(SSOT) 감사를 모두 수행합니다.
  - **계층 2 (`TestDependencyInjection`)**: `AGS.mq5` OnInit 단계에서 실행되며 6개 핵심 서비스 확인 및 오케스트레이터 재귀 `Bind()`를 다시 실행합니다.
  - *분석*: 두 계층 모두에서 오케스트레이터의 재귀 `Bind()` 전파를 중복으로 수행합니다. 초기화 단계이므로 미세한 오버헤드지만, 단일 계산 소스(SSOC) 관점에서 검증 로직이 분산된 느낌을 줍니다.
  - *의견*: `TestDependencyInjection::Verify`를 간소화하고, 모든 구조적 정합성 검증 책임을 `CXIntegrityGuard`로 일원화(SSOC)하는 방안을 권장합니다.

### 2.4. Pure Task 설계의 정합성
- 외부 의존성이 없는 순수 비즈니스 로직 태스크(`CXTaskExit_L_Prepare`, `CXTaskExit_V_Error`)가 `IXTask::Bind()` 기본 구현(`true` 반환)에 의존하는 설계는 결합도를 낮추는 **올바른 설계 방향**입니다.

---

## 3. 권장 조치 사항 (Action Items)

### [Action 1] `DESIGN_PRE_VALIDATED_BINDING_v2.0.md` 문서 이력 섹션 보강
- `GEMINI.md` 표준 규격에 부합하도록 문서 상단에 아래와 같은 `Document History` 테이블을 추가합니다.

| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-29 | Initial PVB (Pre-Validated Binding) Pattern design. | System |
| v2.0 | 2026-05-30 | Expanded with 15-task coverage analysis, 2-layer verification flow, and Unit Test strategy. | System |

### [Action 2] 중복 바인딩 검증 간소화 및 일원화
- `TestDependencyInjection`에서는 서비스 존재 여부(6개 핵심) 등 단순 연결만 최종 확인하고, 오케스트레이터 그래프 전체의 무결성 검증 및 재귀 바인딩은 `CXIntegrityGuard`가 단독으로 완결하도록 아키텍처 역할을 재정의합니다.
- 이를 통해 초기화 단계의 중복 실행 오버헤드와 분산된 검증 책임을 정리합니다.

### [Action 3] Phase 5 (단위 테스트 `TestPVBIntegrity`) 마무리 및 활성화
- `TestPVBIntegrity.mqh`가 `AGSTestRunner`에 올바르게 통합되어 동작하는지 빌드 성공 여부를 확인합니다.
