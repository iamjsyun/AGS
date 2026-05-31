# PLAN: AGS 아키텍처 정비 및 단위 테스트 마스터 구현 계획서 (v1.2)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 초기 마스터 실행 로드맵 수립 (세분화, DI 테스트 연동) | Antigravity |
| v1.1 | 2026-05-31 | DB 스킹마 무결성 검증 및 런타임 보호 로직(Phase 5) 추가 | Antigravity |
| v1.2 | 2026-05-31 | [추가] 하이퍼-아토마이제이션(Hyper-Atomization) 원자 단위 테스트(Phase 6) 반영 | Antigravity |

---

**Status**: In Progress  
**Author**: Antigravity  
**Reference**: 
- [PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.2.md](PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.2.md)
- [PLAN_CLASS_SUBDIVISION_REFACTORING_v1.0.md](PLAN_CLASS_SUBDIVISION_REFACTORING_v1.0.md)
- [PLAN_TASK_DI_UNIT_TEST_v1.0.md](PLAN_TASK_DI_UNIT_TEST_v1.0.md)

---

## 1. 개요 (Overview)

본 마스터 계획서는 AGS 엔진의 안정성 및 무결성을 보장하기 위한 통합 로드맵입니다. **Phase 6**에서는 기존 매니저 클래스들을 기능적으로 완전히 쪼개는 **하이퍼-아토마이제이션** 전략을 도입하여, 엔진의 모든 계산부와 판별부를 터미널 연결 없이 100% 원자 단위로 검증하는 초정밀 테스트 환경을 구축합니다.

---

## 2. 통합 실행 로드맵 (Integrated Roadmap)

### [Phase 1~5] (기존 계획 수행 완료 및 진행 중)
- 클래스 세분화(1단계), Smart PVB, 부트스트랩 가드, DB 스키마 무결성 보호 포함.

### [Phase 6] 하이퍼-아토마이제이션 및 원자 단위 테스트 (New)
매니저 클래스를 더 작은 순수 로직(Pure Logic) 부품으로 분해하여 테스트 결정성을 극대화합니다.

#### 6.1. 원자 단위 클래스 추출 (Sub-component Splitting)
- **Terminal 원자화**: `CXHistoryNavigator`(커서 이동), `CXDealInterpreter`(속성 해석), `CXAccountMonitor`(수치 감지)
- **Order 원자화**: `CXStopsGuard`(거리 검증), `CXOrderTransformer`(요청 변환)
- **Risk 원자화**: `CXLotStepAligner`(로트 정렬), `CXMarginQuoter`(증거금 산출)
- **Price 원자화**: `CXTickScraper`(가격 정규화), `CXPriceInverter`(방향 반전)

#### 6.2. 원자 단위 테스트(Atomic Unit Tests) 1:1 매칭
- 추출된 각 원자 클래스별로 전용 테스트 클래스를 `MT5/99_TestFramework/UnitTests/Atomic/`에 생성.
- MT5 API 모의 없이, 입력값에 대한 출력값의 수학적/논리적 일치 여부만 초고속으로 전수 검사.

#### 6.3. 컴포지션 기반 매니저 재조립
- 기존 매니저 클래스들이 MT5 API를 직접 호출하는 대신, 검증된 원자 부품들을 조합하여 상위 기능을 수행하도록 구조 변경.

---

## 3. 핵심 검증 매트릭스 (Success Metrics)

| 검증 항목 | 합격 기준 (Success Criteria) |
| :--- | :--- |
| **원자 테스트 성공율** | 신규 생성된 10개 이상의 원자 클래스 테스트 100% Pass |
| **순수 로직 격리** | 원자 클래스 내부에서 MT5 시스템 함수(`OrderSend` 등) 직접 호출 제로화 |
| **코드 라인 수** | 원자 클래스당 평균 50라인 이하의 극도의 간결함 유지 |

---

## 4. 기대 효과
- **결정론적 신뢰성**: 시장 상황과 관계없이 모든 계산 로직이 수학적으로 완벽함을 보장.
- **초고속 피드백**: 수백 개의 원자 단위 테스트를 밀리초(ms) 단위로 실행하여 개발 즉시 결함 발견.
- **디버깅 정밀도**: 시스템 오류 발생 시 어떤 원자 부품에서 논리적 위반이 발생했는지 즉각적인 추적 가능.
