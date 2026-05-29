# [PLAN] AGS v2.0 Refactoring: Architectural Consolidation

**Version**: v1.0  
**Status**: Draft/Planned  
**Date**: 2026-05-29  
**Goal**: Performance Optimization & Maintenance Efficiency via PVB and UDP Patterns

## 1. 목적 (Objectives)
- **성능 최적화**: 런타임 Hash Map 조회 및 불필요한 조건 분기 제거.
- **아키텍처 일관성**: 전역/지역 컨텍스트와 데이터 파라미터의 통합 관리.
- **코드 품질 향상**: 핵심 비즈니스 로직에서 인프라/검증 코드를 분리하여 가독성 증대.
- **Fail-Fast 구현**: 기동 시점에 모든 의존성을 확정하여 런타임 안정성 보장.

## 2. 주요 리팩토링 요소 (Core Components)
1.  **PVB (Pre-Validated Binding)**: `IXTask`, `IXStage`에 사전 바인딩 단계 도입.
2.  **UDP (Universal Data Parameter)**: `CXParam`을 통합 데이터/컨텍스트 운반체로 고도화.
3.  **Context Synchronization**: `GlobalContext`와 `LocalContext` 간의 역할 및 계층 구조 명확화.

## 3. 단계별 이행 로드맵 (Phased Roadmap)

### Phase 1: Foundation (기반 구축)
- **대상**: `ICXParam`, `ICXContext`, `IXTask`, `IXStage` 인터페이스.
- **작업**: 
    - `ICXParam`에 동적 속성 및 컨텍스트 접근 메서드 추가.
    - `IXTask`, `IXStage`에 `Bind(ICXContext*)` 가상 함수 정의.
    - `CXParamUDP` 기본 골격 구현.

### Phase 2: Core Implementation (코어 엔진 개조)
- **대상**: `CXFluentSequence`, `CXCompositeStage`, `CXAppService`.
- **작업**:
    - `CXFluentSequence`의 실행 루프(`Pulse`)에서 UDP 지원.
    - `CXCompositeStage`의 태스크 체이닝 시 `Bind()` 전파 로직 추가.
    - `CXAppService` 기동 시 전역 바인딩 검증(Validation) 절차 통합.

### Phase 3: Component Refactoring (컴포넌트 리팩토링)
- **대상**: 모든 `IXTask` 구현체 및 `Watcher`, `Session` 스테이지.
- **작업**:
    - 기존의 `CX_GET_OBJ` 조회를 `Bind()` 시점의 멤버 변수 캐싱으로 전환.
    - `Execute()` 내의 중복 `IS_INVALID` 검사 제거.
    - 로직 간 데이터 전달을 `UDP`의 Dynamic Property로 교체.

### Phase 4: Validation & Stabilization (검증 및 안정화)
- **대상**: 전체 시스템 및 단위 테스트.
- **작업**:
    - 의존성 누락 시 Fail-Fast 정상 작동 여부 확인.
    - 리팩토링 전후의 CPU 사용률 및 실행 속도 비교 측정.
    - 회귀 테스트를 통한 기존 트레이딩 로직 무결성 확인.

## 4. 상세 마일스톤 (Milestones)
- **M1**: 인터페이스 규격 확정 및 UDP 프로토타입 완료 (T+1)
- **M2**: 코어 엔진(Sequence/Stage) PVB 지원 업데이트 (T+2)
- **M3**: 핵심 태스크군(Active/Trailing) 전환 완료 (T+3)
- **M4**: 전체 리팩토링 완료 및 통합 테스트 통과 (T+5)

## 5. 리스크 관리 (Risks & Mitigations)
- **리스크**: 대규모 리팩토링에 따른 기존 로직의 의도치 않은 변형.
- **대응**: 
    - 단계별 커밋 및 `bags.ps1`을 통한 지속적 빌드 확인.
    - `_Test` 시나리오 러너를 활용한 행동 기반(Behavioral) 검증 병행.
    - 주요 변경점마다 소스 코드 정적 분석(Linter) 활용.
