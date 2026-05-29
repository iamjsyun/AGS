# [Plan] AGS v2.2 Proactive Integrity Guard Enhancement

## 1. Overview
이 계획서는 `CXIntegrityGuard`를 고도화하여 메모리 이중 해제(Double Free), 자원 누수(DB Leak), 파일 확장자 불일치 등의 치명적 오류를 시스템 기동(`OnInit`) 시점에 100% 사전 차단하는 것을 목표로 합니다.

---

## 2. Implementation Phases

### Phase 1: Context Ownership Tracking
- **목표**: `CXContext`가 등록된 객체의 소유권(수명주기 권한)을 추적할 수 있도록 인터페이스 확장.
- **작업 내역**:
  - `ICXContext.mqh` 및 `CXContext.mqh` 수정.
  - `Register(string key, CObject* obj, bool isManaged)` 형태의 오버로딩 추가.
  - 관리되는 객체(`isManaged=true`)의 경우 `CXContext` 소멸 시 자동 해제(`delete`)하도록 내부 컬렉션 분리.

### Phase 2: Integrity Guard Expansion
- **목표**: `CXIntegrityGuard`에 사전 환경 및 자원 단일성 검사 로직 추가.
- **작업 내역**:
  - `ICXIntegrityGuard.mqh` 및 `CXIntegrityGuard.mqh` 수정.
  - `AuditEnvironment(string scenarioFile)`: 파일 확장자(`.tsd`) 및 물리적 존재 유무 사전 스캔.
  - `AuditOwnership(ICXContext* ctx)`: `isManaged` 플래그를 감사하여 AppService의 라이프사이클 델리게이션 상태 점검.
  - `AuditResources(ICXContext* ctx)`: 단일 인스턴스 패턴 위반(예: 여러 개의 DB 핸들 포인터) 검사.

### Phase 3: Runner & AppService Integration
- **목표**: 테스트 러너와 앱 서비스에 고도화된 검사기 적용.
- **작업 내역**:
  - `AGSScenarioRunner.mq5`의 `OnInit()` 최상단에서 `Guard.AuditEnvironment()` 호출 (실패 시 즉각 자폭).
  - `CXAppService.mqh`에서 Context에 객체 등록 시 `isManaged` 플래그 명시적 사용. (AppService가 직접 파괴하는 객체는 `false`로 등록하여 이중 해제 원천 방지).

---

## 3. Success Criteria
1. TSDL 시나리오 파일 확장자 오타 주입 시 파서(Parser) 진입 전 `INIT_FAILED` 발생 및 안내 메시지 출력.
2. `CXAppService`와 Runner에서 동일한 포인터 객체(예: DB나 Config)를 중복 해제할 가능성이 구조적으로 제거됨.
3. 컴파일 시 에러 및 워닝이 0개(Zero-warnings) 유지됨.