# [Design] CXStageSystemSetup 독립 폴더 격상 설계 장단점 분석서 (v1.0)

**Status**: Proposed  
**Author**: Antigravity  
**Target**: `CXStageSystemSetup`을 기존 `Workflow/Watcher`에서 `Workflow/Bootstrap` (또는 `SystemSetup`)으로 분리 및 격상할 때의 아키텍처적 유용성을 평가함.

---

## 1. 개요 (Context)

현재 `CXStageSystemSetup`은 시스템 기동과 최초 시퀀스 상태를 바인딩하는 역할을 수행하지만, 감시 계층의 모듈들이 모여 있는 `Workflow/Watcher/` 폴더 하위에 위치하고 있습니다. 

이는 시스템의 라이프사이클 중 **'기동(Bootstrap)'**과 **'지속 감시(Watcher)'**라는 상이한 책임 영역이 물리적으로 결합되어 있음을 의미합니다. 이 문서는 이를 독립적인 물리적 계층(폴더)으로 분격 설계할 때의 장단점을 다룹니다.

---

## 2. 격상 설계 모델 구조 (Proposed Model Layout)

기존 구조와 제안 구조의 물리 배치 차이는 다음과 같습니다.

### 기존 배치 (As-Is)
```text
Include/AGS/Workflow/
└── Watcher/
    ├── CXStageEntryDiscovery.mqh
    ├── CXStageEntryExecute.mqh
    ├── CXStageExitDiscovery.mqh
    ├── CXStageExitExecute.mqh
    └── CXStageSystemSetup.mqh     # <- 감시 계층 내부에서 기동 제어를 담당
```

### 제안 배치 (To-Be)
```text
Include/AGS/Workflow/
├── Bootstrap/                   # <- 기동/부트스트랩 전용 계층 신설
│   └── CXStageSystemSetup.mqh
└── Watcher/                     # <- 순수 신호 감시 계층으로 정제
    ├── CXStageEntryDiscovery.mqh
    ├── CXStageEntryExecute.mqh
    ├── CXStageExitDiscovery.mqh
    └── CXStageExitExecute.mqh
```

---

## 3. 장단점 분석 (Pros & Cons)

### 3.1 장점 (Pros)

1.  **관심사의 명확한 분리 (Separation of Concerns - SoC)**:
    - `Watcher` 계층이 "SQLite 신호 탐색 및 체결 감시"라는 하나의 비즈니스 도메인 책임에만 오롯이 집중(High Cohesion)하게 됩니다.
    - 시스템의 시동 및 라이브러리 검증이라는 시스템 성격의 로직이 별도 계층으로 도식화됩니다.
2.  **부트스트랩 확장성 확보 (Extensibility)**:
    - 차후 라이선스 암호 키 검증, 원격 서버 핸드셰이크(Network Auth), 버전 호환성 자동 체크 등 **'기동 전처리 단계'**가 추가될 때, `Bootstrap/` 디렉토리에 태스크들을 모아 `CXCompositeStage` 형태로 쉽게 시동 단계를 고도화할 수 있습니다.
3.  **코드 탐색성 향상 (Maintainability)**:
    - 시스템 신입 개발자나 공동 작업자가 프로젝트를 처음 분석할 때, 시동 경로와 핵심 루프 경로를 혼동하지 않고 `Bootstrap/` 폴더를 통해 시스템의 입구를 한눈에 찾을 수 있습니다.

### 3.2 단점 (Cons)

1.  **폴더 비대화 오버헤드 (Folder Bloat)**:
    - 현재 기준으로는 `CXStageSystemSetup.mqh` 단 한 개의 파일만을 위해 폴더 하나를 별도로 생성하고 관리해야 하므로 물리적 오버헤드가 다소 과도하게 느껴질 수 있습니다.
2.  **include 상대 경로 변경 공수**:
    - 파일 이전에 따라 `AppOrchestrator.mqh` 및 `CXStageFactory.mqh` 등 공장 클래스들의 include 경로가 변경되어야 합니다. (단, 앞서 정의한 꺾쇠괄호 `<AGS\Workflow\Bootstrap\...>` 절대경로화가 선행된다면 이 문제는 원천 해소됩니다.)
3.  **종속성 참조 결합**:
    - `CXStageSystemSetup`은 성공적으로 시스템 구성이 완료되면 반드시 `WATCHER_ENTRY_DISCOVERY`로의 전이(Id)를 반환해야 하므로 결국 `Watcher` 상태 ID에 종속됩니다. 폴더를 물리적으로 쪼개더라도 논리적인 상호 종속관계는 차단할 수 없습니다.

---

## 4. 종합 평가 및 추천안 (Recommendation)

### 추천 수준: **강력 권장 (Highly Recommended)**

*   **판단 근거**: 단순 파일 관리 측면만 본다면 폴더가 하나 느는 것이 단점일 수 있으나, **아키텍처의 직관성(System Architecture Intuition)** 측면에서 기동 로직과 틱당 감시 로직이 한 폴더에 있는 것은 장기적으로 코드 혼탁도를 높입니다.
*   **시너지**: 프로젝트 디렉토리 재배치 설계(v1.0)와 맞물려 `<AGS\Workflow\Bootstrap\CXStageSystemSetup.mqh>` 표준 인클루드 주소로 선제 개편하는 것을 제안합니다.
