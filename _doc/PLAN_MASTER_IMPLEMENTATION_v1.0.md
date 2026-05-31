# PLAN: AGS 아키텍처 정비 및 단위 테스트 마스터 구현 계획서 (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | 개별 계획서(정비, 세분화, DI 테스트)를 통합한 마스터 실행 로드맵 수립 | Antigravity |

---

**Status**: Proposed  
**Author**: Antigravity  
**Reference**: 
- [PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.2.md](PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.2.md)
- [PLAN_CLASS_SUBDIVISION_REFACTORING_v1.0.md](PLAN_CLASS_SUBDIVISION_REFACTORING_v1.0.md)
- [PLAN_TASK_DI_UNIT_TEST_v1.0.md](PLAN_TASK_DI_UNIT_TEST_v1.0.md)

---

## 1. 개요 (Overview)

본 마스터 계획서는 AGS 엔진의 안정성, 확장성 및 테스트 자동화를 위해 수립된 개별 실행 계획들을 하나의 통합된 타임라인으로 정렬한 로드맵입니다. **"클래스 세분화 → 의존성 무결성 확보 → 전체 자동 테스트 검증"**의 순서로 진행하여 엔진의 기술적 부채를 해결하고 무결성을 보장합니다.

---

## 2. 통합 실행 로드맵 (Integrated Roadmap)

### [Phase 1] 고위험 로직 분리 및 클래스 세분화 (Subdivision)
물리 계층(MT5 API)과 비즈니스 판별 로직을 분리하여 테스트 가능성을 확보합니다.
1.  **Terminal 분리**: `CXTerminalPlatform` → `CXHistoryAnalyzer` 추출 및 단위 테스트 작성.
2.  **Order 분리**: `CXOrderManager` → `CXOrderValidator` 추출 및 단위 테스트 작성.
3.  **Price/Risk 분리**: `CXPriceNormalizer` 및 `CXRiskEvaluator` 추출.

### [Phase 2] DI 무결성 및 PVB 고도화 (Smart Testing)
세분화된 클래스들과 기존 태스크들의 의존성 주입 체계를 자동 검증합니다.
1.  **Smart PVB 구현**: `IXTask`에 `GetRequiredServices()` 계약 추가 및 자동 스캔 루틴 탑재.
2.  **그래프 감사**: `AppOrchestrator` 시퀀스 맵의 순환 참조 및 노드 연결 정합성 전수 검사.
3.  **Composite 검증**: 복합 스테이지의 재귀적 바인딩 및 Fail-Fast 로직 강화.

### [Phase 3] 시스템 부트스트랩 가드 강화 (Integrity Guard)
단위 테스트의 성과를 실제 엔진 구동 프로세스에 결합합니다.
1.  **부트스트랩 동기화**: `CXIntegrityGuard`가 Phase 2의 DI 스캔 결과를 부팅 시 확인하도록 연동.
2.  **검증 로직 중앙화**: 산재된 `IS_VALID` 체크를 부트스트랩 가드 단계로 집중시켜 런타임 성능 최적화.

### [Phase 4] 최종 통합 검증 및 빌드 복구 완료
모든 리팩토링이 기존 거래 로직에 영향을 주지 않았음을 증명합니다.
1.  **빌드 검증**: `build_ags_main.ps1` 및 `build_tests.ps1` 실행 (종료 코드 0 확인).
2.  **시나리오 전수 테스트**: 22종의 TSDL E2E 시나리오를 Mock 환경에서 전행 실행하여 회귀(Regression) 여부 확인.
3.  **아카이브 정비**: 작업 중 생성된 임시 파일 및 로그 정리.

---

## 3. 핵심 검증 매트릭스 (Success Metrics)

| 검증 항목 | 합격 기준 (Success Criteria) |
| :--- | :--- |
| **빌드 성공율** | 전 모듈 100% 컴파일 성공 (Syntax & Link) |
| **단위 테스트** | 신규 생성된 4개 단위 클래스 및 DI 테스트 전원 통과 |
| **시나리오 테스트** | `run_all_scenarios.ps1` 실행 결과 22개 시나리오 100% Pass |
| **코드 가독성** | 핵심 매니저 파일당 라인 수 150라인 미만으로 축소 |

---

## 4. 기대 효과
- **견고한 인프라**: 실행 전 모든 결함을 잡아내는 선제적 방어 체계 구축.
- **빠른 개발 주기**: 세분화된 클래스 덕분에 기능 수정 시 영향 범위 파악 및 테스트가 초 단위로 가능.
- **품질 가시성**: 마스터 계획에 따른 단계별 검증 결과가 리포트로 자산화됨.
