# [DESIGN] AGS v2.0: Pre-Validated Binding (PVB) Pattern

**Version**: v1.0  
**Status**: Proposed  
**Date**: 2026-05-29  
**Target**: Reduce Runtime Overhead & Improve System Stability

## 1. 개요 (Background)
AGS(Automated Grid System)는 인터페이스 기반의 유연한 구조를 가지고 있으나, 현재 모든 태스크(`IXTask`)와 스테이지(`IXStage`)가 실행 시점(`Execute`)마다 필요한 서비스를 컨텍스트에서 조회하고 유효성을 검증하는 방식을 사용하고 있습니다. 이는 고주파 연산 환경에서 불필요한 CPU 오버헤드를 발생시키며, 핵심 로직의 가독성을 저해하는 요인이 됩니다.

## 2. 문제 정의 (Problem Statement)
- **반복적 조회 비용**: 매 틱마다 Hash Map 기반의 서비스 조회가 반복됨.
- **인프라 코드의 혼재**: 비즈니스 로직 사이에 `IS_INVALID` 등 검증 코드가 산재하여 유지보수가 어려움.
- **지연된 실패 (Late Failure)**: 기동 시점에 발견할 수 있는 의존성 결함이 실제 거래 로직 실행 중에 발생함.

## 3. 제안 솔루션 (Proposed Solution)

### 3.1 "Bind-then-Trust" 원칙
"조립 시점에 딱 한 번 검증하고, 실행 시점에는 검증된 포인터를 신뢰한다"는 원칙을 적용합니다.

### 3.2 핵심 변경 사항
1.  **Dependency Caching**: 태스크 및 스테이지 클래스 내부에 필요한 서비스 포인터를 멤버 변수로 캐싱합니다.
2.  **Explicit Binding Phase**: `Execute()`와 분리된 `Bind(ICXContext* ctx)` 단계를 도입하여 조립 직후 의존성을 주입합니다.
3.  **Fail-Fast Initialization**: 시스템 기동 시 모든 바인딩을 수행하며, 하나라도 실패할 경우 EA 기동을 차단합니다.

## 4. 상세 설계 (Implementation Detail)

### 4.1 기본 인터페이스 확장 (`IXTask.mqh`)
```cpp
class IXTask : public CObject {
protected:
    bool m_isBound; 
public:
    IXTask() : m_isBound(false) {}
    
    /**
     * @brief [v2.0] 의존성 주입 및 사전 검증
     * @return 성공 시 true, 필수 의존성 누락 시 false
     */
    virtual bool Bind(ICXContext* ctx) { return m_isBound = true; }
};
```

### 4.2 태스크 구현 예시
```cpp
class CXTaskActive_P_Align : public IXTask {
private:
    IRepository*       m_repo;   // 캐싱된 서비스
    IXPositionManager* m_posMgr;

public:
    virtual bool Bind(ICXContext* ctx) override {
        m_repo   = CX_GET_OBJ(ctx, "repo", IRepository);
        m_posMgr = CX_GET_OBJ(ctx, "pos_mgr", IXPositionManager);
        return (m_repo != NULL && m_posMgr != NULL);
    }

    virtual int Execute(ICXParam* xp, ICXContext* ctx) override {
        // [v2.0] 검증 없이 즉시 사용
        if(!m_repo.UpdateStatus(xp.GetSignal())) { ... }
        return TASK_CONTINUE;
    }
};
```

### 4.3 스테이지 및 팩토리 연동
- `CXCompositeStage`는 추가된 태스크들에 대해 루프를 돌며 `Bind()`를 전파합니다.
- `CXAppService`는 전체 시퀀스 조립 후 최상위에서 `Bind()`를 호출하여 정합성을 최종 확인합니다.

## 5. 기대 효과 (Expected Benefits)
- **성능 향상**: 런타임 Hash Map 조회 비용 제거.
- **코드 가용성**: `Execute` 함수의 획기적인 단순화 (최대 30% 코드량 감소).
- **안정성 확보**: 기동 즉시 의존성 문제를 발견하여 런타임 Null Pointer Crash 방지.

## 6. 이행 계획 (Roadmap)
1.  **Phase 1**: `IXTask`, `IXStage` 인터페이스 수정 및 `Bind` 기반 마련.
2.  **Phase 2**: `Active` 및 `Trailing` 핵심 태스크군에 PVB 패턴 적용.
3.  **Phase 3**: 전역 바인딩 검증 로직 `CXAppService`에 통합.
4.  **Phase 4**: 기존 `Execute` 내의 중복 검증 코드 제거 및 리팩토링.
