# PLAN: AGS 아키텍처 정비 및 단위 테스트 마스터 구현 계획서 (v1.1)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 초기 마스터 실행 로드맵 수립 (세분화, DI 테스트 연동) | Antigravity |
| v1.1 | 2026-05-31 | [추가] DB 스키마 무결성 검증 및 런타임 보호 로직(Phase 5) 반영 | Antigravity |

---

**Status**: In Progress  
**Author**: Antigravity  
**Reference**: 
- [PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.2.md](PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.2.md)
- [PLAN_CLASS_SUBDIVISION_REFACTORING_v1.0.md](PLAN_CLASS_SUBDIVISION_REFACTORING_v1.0.md)
- [PLAN_TASK_DI_UNIT_TEST_v1.0.md](PLAN_TASK_DI_UNIT_TEST_v1.0.md)

---

## 1. 개요 (Overview)

본 마스터 계획서는 AGS 엔진의 안정성 및 무결성을 보장하기 위한 통합 로드맵입니다. **Phase 5**에서는 DB 스키마 불일치로 인한 런타임 오류를 초기화 단계에서 선제적으로 차단하고, 예외 상황 발생 시 사용자에게 시각적 경고와 함께 안전한 종료를 보장하는 **DB 스키마 PVB 체계**를 구축합니다.

---

## 2. 통합 실행 로드맵 (Integrated Roadmap)

### [Phase 1~4] (기존 계획 유지 및 수행 중)
- 클래스 세분화, Smart PVB 구현, 시스템 부트스트랩 가드 강화 및 최종 통합 검증 포함.

### [Phase 5] DB 스키마 무결성 및 런타임 보호 (New)
데이터베이스 구조의 정합성을 보장하고 구조적 결함 발생 시 시스템을 안전하게 보호합니다.

#### 5.1. DDL 기반 부트스트랩 검증 (Bootstrap PVB)
- **조건부 실행**: `Experts/AGS/` 또는 `Common/Files/AGS/` 경로에 **`DDL.TXT`** 파일 존재 시에만 스키마 체크 수행.
- **검증 로직**: `PRAGMA table_info('signals')` 결과와 `DDL.TXT` 내 정의된 컬럼 목록을 1:1 대조.
- **불일치 대응**: 컬럼 누락이나 타입 불일치 발견 시 `FATAL` 오류 로그 발생 및 초기화 즉각 중단.

#### 5.2. 유연한 신뢰 모드 (Trust-on-Missing-DDL)
- **작동 방식**: `DDL.TXT` 파일이 제공되지 않을 경우, 현재의 DB 스키마를 신뢰(Trust)하고 엔진 구동.
- **목적**: 설정 파일 관리 부담을 줄이면서도 개발/테스트 환경에서의 편의성 제공.

#### 5.3. 런타임 스키마 가드 (Runtime Schema Guard)
- **오류 감지**: 실행 중 스키마 참조 에러(예: SQL Error 1 - no such column) 발생 시 트래핑.
- **사용자 알림**: `MessageBox()`를 호출하여 스키마 오류 내용과 복구 방법(DB 삭제 후 재시작 등)을 팝업으로 명시.
- **안전 종료**: `ExpertRemove()`를 즉시 호출하여 잘못된 데이터 기반의 오거래 발생 가능성을 원천 차단.

---

## 3. 핵심 검증 매트릭스 (Success Metrics)

| 검증 항목 | 합격 기준 (Success Criteria) |
| :--- | :--- |
| **스키마 PVB** | `DDL.TXT` 수정 후 EA 재구동 시 즉각적인 초기화 실패(Fail-Fast) 확인 |
| **런타임 가드** | 임의의 컬럼 삭제 후 거래 시도 시 MessageBox 노출 및 EA 자동 언로드 확인 |
| **빌드 성공율** | 전 모듈 100% 컴파일 성공 (Syntax & Link) |

---

## 4. 기대 효과
- **데이터 안정성**: 잘못된 DB 구조로 인한 비정상적인 데이터 기록 및 엔진 크래시 방지.
- **운영 투명성**: 문제 발생 시 사용자에게 명확한 실패 원인(Pop-up)을 제공하여 기술 지원 및 조치 속도 향상.
- **구조적 견고함**: 인프라(DB) 영역까지 PVB 철학이 확장되어 엔진 전체의 신뢰성 극대화.
