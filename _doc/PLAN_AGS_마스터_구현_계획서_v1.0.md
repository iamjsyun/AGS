# PLAN: AGS v2.0 마스터 구현 계획서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | AGS v2.0 리팩토링 및 폴더 정비 로드맵을 통합한 마스터 구현 계획서 최초 작성. | Antigravity |

**Status**: Draft  
**Author**: Antigravity  
**Target**: AGS v2.0 시스템 리팩토링 및 안정화 전체 프로세스  
**Reference**: [GEMINI.md](file:///d:/Projects/AGS/GEMINI.md), [DESIGN_PRE_VALIDATED_BINDING_v2.0.md](file:///d:/Projects/AGS/_doc/DESIGN_PRE_VALIDATED_BINDING_v2.0.md), [PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.0.md](file:///d:/Projects/AGS/_doc/PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.0.md)

---

## 1. 개요 (Overview)

본 문서는 AGS(Active Trading Session Engine) v2.0으로의 아키텍처 개조 및 리팩토링 작업을 일관성 있고 안전하게 추진하기 위한 **통합 마스터 구현 계획서(Master Implementation Plan)**입니다. 

의존성 주입 최적화(PVB), 데이터 운반 표준화(UDP), 폴더 구조 정비, 그리고 안정성 검증 시나리오를 연계하여 프로젝트의 최종 빌드 성공 및 실거래 무결성을 확보하는 것을 목표로 합니다.

---

## 2. 핵심 추진 과제 (Core Work Items)

### 2.1. 폴더 구조 정비 및 컴파일 에러 복구
- **에러 해결**: `CXPositionManager.mqh` 내 26개 지점의 `CXLogDispatcher::Ok` 호출을 `IsOk`로 수정하여 컴파일 오류 199 차단.
- **구조 정비**: 레거시 디렉토리(`MT5/Session`, `MT5/_Test`) 및 루트 EX5 파일 제거. `Test/03_Results` 및 `Test/04_Logs` 생성.
- **상세 내용**: [PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.0.md](file:///d:/Projects/AGS/_doc/PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.0.md) 참조.

### 2.2. PVB (Pre-Validated Binding) 적용
- **목적**: 런타임 HashMap 조회 비용 제거 및 의존성 주입 사전 검증(Fail-Fast).
- **적용 대상**: 전체 15개 태스크 중 서비스 의존성이 있는 13개 태스크 전수 전환 완료.
- **검증 계층**: `CXIntegrityGuard`(14개 전역 서비스 감사) + `TestDependencyInjection`(6개 핵심 서비스 검증) 2계층 구조 동작.
- **상세 내용**: [DESIGN_PRE_VALIDATED_BINDING_v2.0.md](file:///d:/Projects/AGS/_doc/DESIGN_PRE_VALIDATED_BINDING_v2.0.md) 참조.

### 2.3. UDP (Universal Data Parameter) 도입
- **목적**: 전역/지역 컨텍스트 및 동적 속성을 안전하게 운반하는 단일 데이터 전송 체계 구현.
- **작업**: `ICXParam` 인터페이스 확장 및 `CXParam` 기반 Dynamic Property 구현을 통한 태스크 간 결합도 완화.

---

## 3. 마스터 로드맵 (Phased Roadmap)

```mermaid
gantt
    title AGS v2.0 마스터 로드맵
    dateFormat  YYYY-MM-DD
    section Phase 1: 복구
    폴더 정비 및 컴파일 에러 복구     :active, p1, 2026-05-31, 1d
    section Phase 2: 코어 고도화
    PVB/UDP 아키텍처 적용 완료       :after p1, p2, 1d
    section Phase 3: 검증 & 안정화
    TestPVBIntegrity 단위 테스트 검증  :after p2, p3, 2d
    TSDL 시나리오 테스트 검증        :after p3, p4, 2d
```

### [Phase 1] 컴파일 오류 해결 및 디렉토리 정비 (현재 진행 중)
- `CXPositionManager.mqh` 수정 및 컴파일 성공률 100% 달성.
- 불필요한 레거시 파편 제거 및 신규 출력 폴더 생성.

### [Phase 2] PVB 및 UDP 최종 적용 및 엔진 결합
- `CXFluentSequence`, `CXCompositeStage` 최적화 및 런타임 Null Pointer 체크 최소화.
- 2계층 정합성 검사 체계(`CXIntegrityGuard` 및 `TestDependencyInjection`) 결합 확인.

### [Phase 3] 단위 테스트 및 시나리오 최종 검증
- `TestPVBIntegrity.mqh`를 통한 13개 태스크 바인딩 및 Fail-Fast 시뮬레이션 성공 검증.
- `bags.ps1` 및 `build_tests.ps1` 검증 통과.
- TSDL 시나리오(트레이링 엔트리, 수동 강제 청산 등) 정상 작동 확인.

---

## 4. 리스크 및 대응 방안 (Risks & Mitigations)

| 리스크 | 파급 효과 | 대응 방안 |
| :--- | :--- | :--- |
| **대규모 리팩토링에 따른 기존 동작 변경** | 런타임 거래 로직 오작동 및 손실 | `TestPVBIntegrity` 단위 테스트 및 TSDL 행동 기반 회귀 테스트 전수 실행 후 승인. |
| **의존성 순환 참조(Circular Dependency)** | OnInit 단계 데드락 또는 빌드 실패 | `CXIntegrityGuard` 소유권 스캔을 통해 이중 소유권 및 불완전 바인딩을 기동 즉시 로깅 및 강제 종료. |
| **플랫폼 업데이트 빌드 오류** | 컴파일 속도 저하 및 터미널 락업 | `Automation/Build` 표준 스크립트 실행으로 매 변경 단위별 로컬 빌드 정합성 상시 모니터링. |

---

## 5. 결론 및 다음 단계
본 마스터 구현 계획은 AGS v2.0 아키텍처 개조의 로드맵 역할을 하며, 첫 단계인 **[Phase 1] 폴더 정비 및 컴파일 에러 복구** 승인 시 바로 관련 태스크를 시작할 것입니다.
