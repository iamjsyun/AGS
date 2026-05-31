# [DESIGN] AGS v2.0: Pre-Validated Binding (PVB) Pattern — 정밀 분석 고도화

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-29 | Initial PVB (Pre-Validated Binding) Pattern design. | System |
| v2.0 | 2026-05-30 | Expanded with 15-task coverage analysis, 2-layer verification flow, and Unit Test strategy. | System |

**Version**: v2.0
**Status**: Active — Fully Implemented & Verified
**Date**: 2026-05-30
**Prev Version**: v1.0 (Proposed)
**Target**: 런타임 오버헤드 제거, 시스템 안정성 극대화, Fail-Fast 아키텍처 확립

---

## 1. 개요 (Background)

AGS(Automated Grid System)는 인터페이스 기반의 유연한 아키텍처를 채택하고 있으며, 모든
태스크(`IXTask`)와 스테이지(`IXStage`)는 "Bind-then-Trust" 원칙에 따라 **조립 시점**에
의존성을 검증하고 **실행 시점**에는 신뢰된 포인터를 그대로 사용하는 패턴을 채택합니다.

v2.0에서는 v1.0의 제안 단계를 넘어, 전체 태스크 15개에 대한 **실제 적용 현황 정밀 분석**과
2계층 검증 아키텍처(`TestDependencyInjection` + `CXIntegrityGuard`)의 내부 동작을 문서화합니다.

---

## 2. 문제 정의 (Problem Statement)

| 문제 | 설명 | 결과 |
|------|------|------|
| **반복적 조회 비용** | 매 틱 Hash Map 기반 서비스 조회 반복 | 불필요한 CPU 오버헤드 |
| **인프라 코드 혼재** | `IS_INVALID`, `ctx.Get()` 검증 코드가 비즈니스 로직에 산재 | 가독성 저하, 유지보수 난이도 증가 |
| **지연된 실패 (Late Failure)** | 기동 시점에 발견 가능한 의존성 결함이 런타임에 발생 | Null Pointer Crash, 실거래 손실 위험 |

---

## 3. 해결책: "Bind-then-Trust" 아키텍처

### 3.1 핵심 원칙

> **"조립 시점에 딱 한 번 검증하고, 실행 시점에는 검증된 포인터를 신뢰한다."**

```
[OnInit 단계]                          [OnTimer/OnTick 단계]
AppService.Initialize()                AssetManager.Pulse()
  → CXIntegrityGuard.Inspect()            → CXCompositeStage.OnProcess()
      → Orchestrator.Bind(ctx)                → IXTask.Execute(xp, ctx)
          → Stage.Bind(ctx)                       ← m_repo.UpdateStatus()  ✅ 검증 없이 직접 사용
              → Task.Bind(ctx)                     ← m_posMgr.Pulse()      ✅ 검증 없이 직접 사용
                  → CX_GET_OBJ() 캐싱
                  → m_isBound = true
```

### 3.2 표준 구현 패턴

모든 서비스 의존성 태스크는 아래 패턴을 준수합니다:

```cpp
class CXTaskXxx_P_Yyy : public IXTask {
private:
    IRepository*       m_repo;    // ← private 멤버 변수로 캐싱
    IXPositionManager* m_posMgr;

public:
    CXTaskXxx_P_Yyy() : m_repo(NULL), m_posMgr(NULL) {}

    virtual string Name() override { return "Xxx_P_Yyy"; }

    virtual bool Bind(ICXContext* ctx) override {
        // 1. CX_GET_OBJ 매크로로 ctx에서 포인터 획득 및 캐싱
        m_repo   = CX_GET_OBJ(ctx, "repo", IRepository);
        m_posMgr = CX_GET_OBJ(ctx, "pos_mgr", IXPositionManager);
        // 2. NULL 검사 — 하나라도 실패 시 false 반환 (Fail-Fast)
        if(IS_INVALID(m_repo) || IS_INVALID(m_posMgr)) return false;
        // 3. 부모 클래스 Bind 호출로 m_isBound = true 설정
        return IXTask::Bind(ctx);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        // ← ctx.Get() 없이 캐싱된 포인터 직접 사용
        m_repo.UpdateStatus(xp.GetSignal());
        return TASK_CONTINUE;
    }
};
```

---

## 4. 전체 태스크 PVB 커버리지 매트릭스 (v2.0 정밀 분석)

### 4.1 Active 태스크 (4/4 — 100%)

| 클래스 | 파일 | Bind() | 캐싱 서비스 | 비고 |
|--------|------|--------|-------------|------|
| `CXTaskSync_V_Stale` | Active/ | ✅ | `repo` | Pending 타임아웃 감시 |
| `CXTaskActive_V_Terminal` | Active/ | ✅ | `asset_mgr` | 포지션 실물 존재 검증 |
| `CXTaskActive_P_Align` | Active/ | ✅ | `repo`, `pos_mgr` | 포지션-세션 정합 조정 |
| `CXTaskIntentWatch` | Active/ | ✅ | `repo`, `asset_mgr` | 매 틱 0번 우선 실행, 수동 종료 감지 |

### 4.2 Exit 태스크 (4/6 — 67% + 2 Pure)

| 클래스 | 파일 | Bind() | 캐싱 서비스 | 분류 |
|--------|------|--------|-------------|------|
| `CXTaskExit_L_Prepare` | Exit/ | ⬜ | 없음 | **Pure Task** (xp/sig만 사용) |
| `CXTaskExit_V_Error` | Exit/ | ⬜ | 없음 | **Pure Task** (IsTimedOut만 사용) |
| `CXTaskExit_P_Finalize` | Exit/ | ✅ | `repo` | DB 청산 완료 기록 |
| `CXTaskExit_P_Lock` | Exit/ | ✅ | `repo` | 청산 락 설정 |
| `CXTaskExit_R_Order` | Exit/ | ✅ | `exit_mgr`, `asset_mgr` | 청산 주문 송신 |
| `CXTaskExit_V_Terminal` | Exit/ | ✅ | `asset_mgr` | 포지션 소멸 감지 |

### 4.3 Pending 태스크 (1/1 — 100%)

| 클래스 | 파일 | Bind() | 캐싱 서비스 | 비고 |
|--------|------|--------|-------------|------|
| `CXTaskPending_V_Sync` | Pending/ | ✅ | `asset_mgr`, `repo` | 대기 주문→포지션 전환 감지 |

### 4.4 Trailing 태스크 (4/4 — 100%)

| 클래스 | 파일 | 생성자 파라미터 | Bind() | 캐싱 서비스 |
|--------|------|----------------|--------|-------------|
| `CXTaskTrail_V_Activate` | Trailing/ | `ENUM_TRAIL_MODE` | ✅ | `price_mgr`, `sym_mgr` |
| `CXTaskTrail_V_Extremum` | Trailing/ | `ENUM_TRAIL_MODE` | ✅ | `price_mgr` |
| `CXTaskTrail_L_Evaluate` | Trailing/ | `ENUM_TRAIL_MODE` | ✅ | `price_mgr`, `sym_mgr` |
| `CXTaskTrail_R_Execute` | Trailing/ | `ENUM_TRAIL_MODE` | ✅ | `order_mgr` |

### 4.5 전체 요약

| 카테고리 | 전체 | Bind 구현 | Pure Task | 커버율 |
|----------|------|-----------|-----------|--------|
| Active | 4 | 4 | 0 | **100%** |
| Exit | 6 | 4 | 2 | 4/4 서비스 의존 100% |
| Pending | 1 | 1 | 0 | **100%** |
| Trailing | 4 | 4 | 0 | **100%** |
| **합계** | **15** | **13** | **2** | **서비스 의존 태스크 100%** |

> [!NOTE]
> **Pure Task 정의**: `CXTaskExit_L_Prepare`, `CXTaskExit_V_Error`는 외부 서비스(repo, asset_mgr 등)에
> 의존하지 않고 `ICXParam`/`ICXSignal` 데이터 및 `IsTimedOut()`만 사용하는 순수 로직 태스크입니다.
> 이는 설계 의도에 따른 **정상적인 Bind 미구현**이며, `IXTask::Bind()` 기본 구현이 `true`를 반환하므로
> CXCompositeStage의 전파 바인딩에서 안전하게 통과합니다.

---

## 5. 2계층 PVB 검증 아키텍처

### 5.1 계층 1: 어셈블리 무결성 검사 — `CXIntegrityGuard`

`CXAppService.Initialize()` 종료 직전에 호출되어 4가지 영역을 전수 검사합니다.

```
CXIntegrityGuard.Inspect(globalCtx, orchestrator)
│
├── AuditServices()   — 14개 필수 서비스 등록 여부 검사
│     requirements: config, logger, orchestrator, guard, db, repo, asset_mgr,
│                   price_mgr, sym_mgr, risk_mgr, exit_mgr, terminal_platform,
│                   order_mgr, pos_mgr
│
├── AuditOrchestrator() — orchestrator.Bind(ctx) 재귀 호출
│     → CXSequenceOrchestrator → CXFluentSequence → CXCompositeStage
│         → 각 IXTask.Bind(ctx) 순차 전파 → 실패 시 즉시 FATAL 출력
│
├── AuditOwnership()  — 이중 관리(Double Free) 위험 스캔
│     동일 포인터가 managed=true로 두 개 키에 등록된 경우 오류 리포트
│
└── AuditResources()  — SSOT(단일 자원) 중복 감사
      IDatabase 구현체가 컨텍스트에 2개 이상 등록된 경우 오류 리포트
```

### 5.2 계층 2: 의존성 주입 정합성 검증 — `TestDependencyInjection`

`AGS.mq5` OnInit에서 `CXAppService.Initialize()` 성공 직후 호출됩니다.

```cpp
// AGS.mq5 OnInit()
if(!TestDependencyInjection::Verify(g_app.GetContext())) {
    Print("Dependency Injection Verification failed. Self-Terminating EA.");
    return INIT_FAILED;  // ← EA 기동 즉시 차단 (Fail-Fast)
}
```

내부적으로 6개 필수 서비스 검사 + `orchestrator.Bind(ctx)` 재호출로
**CXIntegrityGuard와 독립적인 이중 확인**을 수행합니다.

### 5.3 2계층 검증 비교 매트릭스

| 검증 항목 | CXIntegrityGuard | TestDependencyInjection |
|-----------|-----------------|------------------------|
| 호출 시점 | AppService.Initialize() 내부 | AGS.mq5 OnInit (외부) |
| 서비스 검사 범위 | 14개 전체 | 6개 핵심 |
| 오케스트레이터 Bind | ✅ 재귀 전파 | ✅ 재귀 전파 |
| 소유권 이중 해제 감사 | ✅ | ❌ |
| SSOT 감사 | ✅ | ❌ |
| 상세 리포트 출력 | ✅ GetDetailedReport() | ✅ Print 형태 |

---

## 6. CXCompositeStage의 Bind 전파 메커니즘

`CXCompositeStage.Bind(ctx)`는 스테이지에 추가된 모든 태스크에 대해 순차적으로
`task.Bind(ctx)`를 호출하여 바인딩 결과를 집계합니다.

```cpp
virtual bool Bind(ICXContext* ctx) override {
    if(!AssertDependencies(ctx)) return false;  // 6개 서비스 사전 검증
    bool success = true;
    for(int i = 0; i < m_taskCount; i++) {
        if(IS_VALID(m_taskPtrs[i])) {
            if(!m_taskPtrs[i].Bind(ctx)) {
                PrintFormat("[FATAL] Task Bind Failed: '%s'", m_taskPtrs[i].Name());
                success = false;  // 실패해도 계속 검사 (전체 오류 리포트 목적)
            }
        }
    }
    return success;
}
```

---

## 7. 단위 테스트 전략 (TestPVBIntegrity)

`TestPVBIntegrity.mqh`는 PVB 패턴 준수 여부를 전용 단위 테스트로 검증합니다.

### 7.1 테스트 섹션 구조

| 섹션 | 목적 | 기대 결과 |
|------|------|-----------|
| Part 1: Full Context | 전체 Mock 서비스 등록 후 13개 태스크 Bind() 전수 검사 | 모두 `true` |
| Part 2: Pure Tasks | 서비스 없는 컨텍스트에서 Pure Task Bind() + Execute() 검사 | Bind() `true`, Execute() 정상 |
| Part 3: Fail-Fast | 서비스 일부 미등록 시 Bind() 실패 여부 검사 | Bind() `false` (Fail-Fast 보장) |

### 7.2 Mock 서비스 레지스트리 (TestPVBIntegrity 내부)

```
CXContext ctx
├── "repo"               → MockRepository
├── "asset_mgr"          → MockAssetManager
├── "pos_mgr"            → MockPositionManager
├── "price_mgr"          → MockPriceManager
├── "terminal_platform"  → MockTerminalPlatform
├── "order_mgr"          → MockOrderManager
├── "exit_mgr"           → MockExitManager
└── "sym_mgr"            → MockSymbolManager
```

---

## 8. 기대 효과 (Expected Benefits)

| 효과 | v1.0 예측 | v2.0 실측 |
|------|-----------|-----------|
| 런타임 HashMap 조회 제거 | 예측 | **적용 완료** (13개 태스크) |
| Execute 코드 단순화 | 최대 30% 감소 예측 | **ctx.Get() 호출 0회** (Execute 내) |
| Null Pointer Crash 방지 | 예측 | **2계층 Fail-Fast로 보장** |
| 기동 시 의존성 결함 조기 발견 | 예측 | **OnInit에서 즉시 차단** |

---

## 9. 이행 현황 (Roadmap Status)

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 1 | `IXTask`, `IXStage` 인터페이스 Bind 기반 마련 | ✅ **완료** |
| Phase 2 | Active / Trailing 핵심 태스크군 PVB 적용 | ✅ **완료** |
| Phase 3 | 전역 바인딩 검증 `CXIntegrityGuard` + `TestDependencyInjection` 통합 | ✅ **완료** |
| Phase 4 | Execute 내 중복 검증 코드 제거 | ✅ **완료** (Execute에 ctx.Get() 없음) |
| **Phase 5** | **전용 단위 테스트 `TestPVBIntegrity` 작성 및 AGSTestRunner 통합** | 🔄 **진행 중** |
