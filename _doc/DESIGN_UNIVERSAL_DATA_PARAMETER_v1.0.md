# [DESIGN] AGS v2.0: Universal Data Parameter (UDP) Pattern

**Version**: v1.0  
**Status**: Proposed  
**Date**: 2026-05-29  
**Target**: Unified Context Management & Flexible Data Passing

## 1. 개요 (Background)
현재 `CXParam`은 고정된 필드(int, double, string 등)만을 가진 단순 DTO 구조입니다. 이로 인해 태스크 간에 동적인 데이터를 전달하거나, 전역(Global) 및 지역(Local) 컨텍스트를 체계적으로 관리하는 데 한계가 있습니다. 시스템이 복잡해짐에 따라 다양한 형태의 데이터를 안전하고 유연하게 운반할 수 있는 통합 파라미터 구조가 필요합니다.

## 2. 설계 목표 (Design Goals)
- **Context Dual-Binding**: 전역 서비스(Global)와 세션 데이터(Local)를 동시에 운반.
- **Dynamic Property Bag**: 미리 정의되지 않은 커스텀 데이터를 키-값 쌍으로 저장 및 조회.
- **High-Performance Fast Slots**: 빈번하게 접근하는 핵심 데이터(Signal, Price, Event)는 직접 필드로 관리하여 성능 유지.
- **Fluent Interface**: 코드 가독성 향상을 위한 체이닝 지원.

## 3. 핵심 구조 (Core Structure)

### 3.1 UDP 데이터 모델
```cpp
class CXParamUDP : public ICXParam {
private:
    // 1. Fast Slots (성능 최적화용)
    ICXSignal*          m_signal;
    ENUM_CX_EVENT       m_event;
    MqlTradeTransaction m_trans;
    
    // 2. Context Binding
    ICXContext*         m_globalCtx; // 시스템 공통 서비스 (Repo, PriceMgr 등)
    ICXContext*         m_localCtx;  // 세션 전용 데이터
    
    // 3. Dynamic Property Bag
    CHashMap<string, long>   m_longs;
    CHashMap<string, double> m_doubles;
    CHashMap<string, string> m_strings;
    CHashMap<string, CObject*> m_objects;

public:
    // ... 구현부 ...
};
```

## 4. 상세 기능 (Detailed Features)

### 4.1 통합 컨텍스트 접근
태스크 내에서 별도의 조회 과정 없이 `UDP`를 통해 즉시 필요한 자원에 접근합니다.
- `param.Global().GetRepo()`
- `param.Local().GetSignal()`
- `param.GetSignal()` // Fast Slot 접근

### 4.2 동적 속성 관리 (Dynamic Properties)
태스크 간의 통신을 위해 임시 데이터를 저장할 수 있습니다.
```cpp
// Task A에서 데이터 설정
param.SetDouble("Custom_EntryPrice", 1.2345)
     .SetInt("Retry_Count", 3);

// Task B에서 데이터 조회
double price = param.GetDouble("Custom_EntryPrice");
```

### 4.3 데이터 생명주기 (Reset & Clone)
- `Reset()`: Fast Slot과 Dynamic Property를 모두 초기화하되, Context 포인터는 유지할지 여부를 옵션으로 제공.
- `Clone()`: 현재 파라미터 상태를 복사하여 병렬 처리에 사용.

## 5. 기대 효과 (Expected Benefits)
- **인터페이스 단순화**: 함수 인자로 `ICXParam*` 하나만 전달해도 모든 컨텍스트와 데이터에 접근 가능.
- **확장성**: 클래스 구조를 수정하지 않고도 새로운 형태의 데이터를 태스크 간에 주고받을 수 있음.
- **일관성**: 전역/지역 컨텍스트 사용 규칙이 단일 객체(UDP)로 강제되어 아키텍처 혼선 방지.

## 6. 이행 계획 (Roadmap)
1.  **Phase 1**: `ICXParam` 인터페이스에 Dynamic Property 및 Context Getter 추가.
2.  **Phase 2**: `CXParamUDP` 구상 클래스 구현.
3.  **Phase 3**: `CXAppService` 및 `CXSessionTask`에서 UDP를 생성 및 주입하도록 변경.
4.  **Phase 4**: 기존 태스크들에서 컨텍스트를 직접 조회하던 코드를 UDP 경유로 리팩토링.
