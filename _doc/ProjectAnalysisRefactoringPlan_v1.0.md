# AGS MQL5 Project Analysis & Refactoring Plan (v1.0)

본 문서는 AGS MQL5 프로젝트의 코드를 정밀 분석하여 비사용 레거시 코드를 검출하고, 오케스트레이션 및 태스크 주입 흐름의 오류 가능성과 위험성을 진단한 뒤, 프로젝트 폴더 구조 리팩토링 설계 및 AI 모델 선택 매트릭스를 제안합니다.

---

## 1. 비사용 레거시 코드 검출 및 제거 계획

자산 중심 아키텍처(v18.30+) 도입에 따라, 진입(Entry) 제어와 물리 자산 획득이 [CXStageEntryExecute](file:///d:/Projects/AGS/MT5/Watcher/WatcherWorkflow/CXStageEntryExecute.mqh) 및 [CXAssetManager](file:///d:/Projects/AGS/MT5/Session/CXAssetManager.mqh#L83)로 일원화되었습니다. 이로 인해 과거 세션 시작 단계에서 개별적으로 수행되던 많은 태스크와 엔진들이 미사용 상태로 남아있습니다.

### 1.1 검출된 레거시 태스크 및 클래스 목록
1. **Entry Workflow Tasks (완전 미사용)**
   - [CXTaskEntry_L_Redirect.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_L_Redirect.mqh) (`TASK_E_L_REDIRECT`)
   - [CXTaskEntry_L_Identity.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_L_Identity.mqh) (`TASK_E_L_IDENTITY`)
   - [CXTaskEntry_L_Risk.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_L_Risk.mqh) (`TASK_E_L_RISK`)
   - [CXTaskEntry_L_Price.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_L_Price.mqh) (`TASK_E_L_PRICE`)
   - [CXTaskEntry_P_Intent.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_P_Intent.mqh) (`TASK_E_P_INTENT`)
   - [CXTaskEntry_L_Validate.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_L_Validate.mqh) (`TASK_E_L_VALIDATE`)
   - [CXTaskGuard_V_Spread.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskGuard_V_Spread.mqh) (`TASK_E_G_SPREAD`)
   - [CXTaskGuard_V_Volatility.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskGuard_V_Volatility.mqh) (`TASK_E_G_VOLATILITY`)
   - [CXTaskEntry_P_Lock.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_P_Lock.mqh) (`TASK_E_P_LOCK`)
   - [CXTaskEntry_R_Order.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_R_Order.mqh) (`TASK_E_R_ORDER`)
   - [CXTaskEntry_V_Error.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_V_Error.mqh) (`TASK_E_V_ERROR`)
   - [CXTaskEntry_V_Ticket.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_V_Ticket.mqh) (`TASK_E_V_TICKET`)
   - [CXTaskEntry_V_Real.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_V_Real.mqh) (`TASK_E_V_REAL`)
   - [CXTaskFinalize_V_DoubleCheck.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskFinalize_V_DoubleCheck.mqh) (`TASK_E_V_DOUBLECHECK`)
   - [CXTaskEntry_P_Finalize.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Entry/CXTaskEntry_P_Finalize.mqh) (`TASK_E_P_FINALIZE`)
   
2. **Pending Workflow Tasks (일부 미사용)**
   - [CXTaskPending_V_Terminal.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Pending/CXTaskPending_V_Terminal.mqh) (`TASK_P_V_TERMINAL`)
   - [CXTaskPending_P_Align.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Pending/CXTaskPending_P_Align.mqh) (`TASK_P_P_ALIGN`)
   - [CXTaskPending_R_Apply.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Pending/CXTaskPending_R_Apply.mqh) (`TASK_P_R_APPLY`)

3. **Active/Cleanup Workflow Tasks (미사용)**
   - [CXTaskActive_R_AlphaApply.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Active/CXTaskActive_R_AlphaApply.mqh) (물리 SL/TP 수정 로직 - 팩토리에 미등록 및 세션 비사용)
   - [CXTaskActive_P_Closed.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Active/CXTaskActive_P_Closed.mqh) (`TASK_ACTIVE_CLOSED`)
   - [CXTaskComm_V_Status.mqh](file:///d:/Projects/AGS/MT5/Session/Workflow/Active/CXTaskComm_V_Status.mqh) (`TASK_A_V_STATUS`)

4. **Unused Engine Classes (완전 미사용)**
   - [CXTrailingEngine.mqh](file:///d:/Projects/AGS/MT5/Platform/Engine/Trailing/CXTrailingEngine.mqh) (트레일링 로직이 태스크 단위로 완전히 파편화/하드코딩되어 인스턴스화되지 않음)

### 1.2 제거 및 정리 계획
- **1단계 (의존성 제거)**: [CXTaskFactory.mqh](file:///d:/Projects/AGS/MT5/App/Orchestration/CXTaskFactory.mqh) 내 `#include` 지시문 및 `CreateTask` 스위치 케이스에서 해당 태스크들의 매핑 코드를 완전히 제거합니다.
- **2단계 (컴파일 및 무결성 검증)**: 빌드 스크립트인 [bags.ps1](file:///d:/Projects/AGS/bags.ps1) 및 [cags.ps1](file:///d:/Projects/AGS/cags.ps1)을 실행하여 의존성 제거 후 컴파일 오류가 없는지 검증합니다.
- **3단계 (물리 파일 삭제 및 커밋)**: 안전성이 확보되면 물리 파일을 삭제하고 git에 최종 커밋합니다.

---

## 2. 오케스트레이션 및 태스크 주입 정밀 분석 및 위험성

오케스트레이션, 스테이지, 시퀀스 간의 주입 방식과 참조 과정을 정밀 분석한 결과, 아래와 같은 구조적 위험 요인과 버그를 발견했습니다.

### 2.1 주요 발견 및 위험 요인

#### 1) 포지션 트레일링(TS) 전이 무력화 (치명적 버그)
- **증상**: [Stage_PositionGovernance](file:///d:/Projects/AGS/MT5/App/Orchestration/AppOrchestrator.mqh#L87) 상태(`POS_MONITORING` = 10)에서 트레일링 스톱 조건이 만족되어 [CXTaskTrail_V_Activate](file:///d:/Projects/AGS/MT5/Session/Workflow/Trailing/CXTaskTrail_V_Activate.mqh#L69)가 작동하면 `xp.SetInt(15)`를 호출하여 `POS_TRAILING`으로의 전이를 요청합니다.
- **오류 분석**: 
  1. `TASK_T_V_ACTIVATE_TS` 바로 다음에 실행되는 `TASK_A_V_TERMINAL` ([CXTaskActive_V_Terminal](file:///d:/Projects/AGS/MT5/Session/Workflow/Active/CXTaskActive_V_Terminal.mqh#L26))이 `xp.SetInt(exists ? 1 : 0)`을 호출함으로써 직전의 `15` 값을 덮어써 유실시킵니다.
  2. 복합 스테이지인 [CXCompositeStage](file:///d:/Projects/AGS/MT5/Session/Workflow/CXCompositeStage.mqh#L128)는 모든 태스크가 `TASK_CONTINUE`(-1)를 반환하므로 최종적으로 `STAGE_SUCCESS`(-100)를 반환합니다.
  3. 시퀀스 엔진 [CXFluentSequence](file:///d:/Projects/AGS/MT5/Platform/Core/Sequence/CXFluentSequence.mqh#L140)는 `STAGE_SUCCESS`를 수신하면 이를 기본 전이 대상인 `if_true` (즉, `POS_MONITORING` = 10)로 강제 매핑합니다.
  4. `next_state`가 현재 상태(`10`)와 동일하므로 루프를 즉시 종료합니다.
- **결과**: TS(Trailing Stop) 조건이 활성화되더라도 세션 상태는 영원히 `POS_MONITORING`에 잔류하며, 실제 트레일링 스톱 작동 단계인 `POS_TRAILING`으로 전이되지 않습니다.
- **보완책**: [CXTaskTrail_V_Activate::Execute](file:///d:/Projects/AGS/MT5/Session/Workflow/Trailing/CXTaskTrail_V_Activate.mqh#L25) 내에서 조건 만족 시 단순히 `xp.SetInt(15)`를 설정하고 `TASK_CONTINUE`를 반환하는 대신, **`SESSION_TRAILING_STOP` (15)을 직접 반환(Return)**하여 복합 스테이지가 루프를 탈출하고 상태 전이를 즉시 수행하도록 보완해야 합니다.

#### 2) 좀비 세션 방지 태스크 (`CXTaskSync_V_Stale`) 미적용 (위험성)
- **증상**: DB 상태 테이블 내 `PENDING_REQ` 상태로 방치된 좀비 레코드를 추적 및 롤백하기 위한 핵심 안전장치인 [CXTaskSync_V_Stale](file:///d:/Projects/AGS/MT5/Session/Workflow/Active/CXTaskSync_V_Stale.mqh)이 팩토리에는 `TASK_A_V_STALE`로 등록되어 있으나, [AppOrchestrator](file:///d:/Projects/AGS/MT5/App/Orchestration/AppOrchestrator.mqh)의 DSL 시퀀스 체인에는 전혀 배치되지 않았습니다.
- **결과**: 통신 장애 등으로 인해 브로커 응답이 유실되면, DB 세션이 영구적으로 대기 상태에 갇히는 데드락 위험이 있습니다.
- **보완책**: `AppOrchestrator` 내 `Stage_OrderOptimization` 시퀀스 마지막 단에 `TASK_A_V_STALE`을 강제로 주입해야 합니다.

#### 3) Context 오염 및 허상 포인터 (Dangling Pointer) 가능성
- **분석**: `CXAssetManager::Pulse` 및 `CXSessionTask::Pulse` 실행 단계에서 하나의 `xp` (Parameter) 객체가 재사용되며 시그널과 컨텍스트가 교차 주입됩니다. `Pulse()` 완료 직후 dangling pointer 방지용 안전 클린업 로직이 존재하지만, 태스크가 예외 발생으로 중단될 경우 하위 컨텍스트에 상위 소멸 객체의 참조가 남아있을 수 있습니다.
- **보완책**: MQL5 환경에서 소멸 시점에 안전하게 참조를 비워주는 `Scoped Context Guard` RAII 패턴을 적용해야 합니다.

---

## 3. 프로젝트 폴더 구조 리팩토링 설계

현재 AGS 프로젝트의 폴더 구조는 핵심 레이어(Core)와 실행 단위(Execution), 도메인 로직(Engine/Workflow)이 혼재되어 있습니다. 이를 도메인 중심의 계층형 아키텍처로 개편할 것을 제안합니다.

### 3.1 제안 아키텍처 레이아웃

```
MT5/
├── Core/                   # 시스템 하위 인프라 레이어
│   ├── Defines/            # 상수, 메세지 딕셔너리 (CXDefine.mqh 등)
│   ├── Interfaces/         # 인터페이스 선언 (ICXParam.mqh 등)
│   ├── Macros/             # 공용 매크로 (CXMacros.mqh)
│   ├── Models/             # 공용 데이터 모델 (CXSignal.mqh, CXConfig.mqh 등)
│   ├── DB/                 # 데이터베이스 관련 모듈 (CXDatabase.mqh)
│   ├── UI/                 # UI, Graph, Chart 요소 (CXUI.mqh, CXChartVisualizer.mqh 등)
│   ├── Logger/             # 로거 프레임워크 (CXLogDispatcher.mqh, CXFileLogger.mqh 등)
│   └── Sequence/           # 플루언트 시퀀스 엔진 (CXFluentSequence.mqh 등)
├── Engine/                 # 비즈니스 도메인 연산 엔진
│   ├── Price/              # 가격 계산 (CXPriceManager.mqh)
│   ├── Risk/               # 리스크 관리 (CXRiskManager.mqh)
│   └── Symbol/             # 심볼 관리 (CXSymbolManager.mqh)
├── Workflow/               # 오케스트레이션 및 파이프라인
│   ├── Orchestration/      # DSL 오케스트레이터, 팩토리 (AppOrchestrator.mqh 등)
│   ├── Watcher/            # 신호 발견 단계 (CXStageEntryDiscovery.mqh 등)
│   ├── Session/            # 자산 관리 태스크 (CXCompositeStage.mqh 등)
│   └── Tasks/              # 세부 마이크로 태스크군
│       ├── Active/
│       ├── Entry/          # (백업 후 제거 예정인 레거시 태스크 폴더)
│       ├── Exit/
│       ├── Pending/
│       └── Trailing/
└── Service/                # 고수준 생명주기 및 브로커 플랫폼 관리자
    ├── App/                # 최상위 기동 서비스 (CXAppService.mqh)
    ├── Watcher/            # 백그라운드 스캐너 (CXSignalWatcher.mqh)
    ├── Session/            # 세션 컨테이너 및 수집기 (CXAssetManager.mqh 등)
    └── Execution/          # 물리 주문 송수신 플랫폼 (Order/Position/Exit manager)
```

---

## 4. 작업 계획용 AI Model Matrix Table

본 리팩토링 및 고도화 계획을 가장 안전하고 효율적으로 수행하기 위한 AI 모델 메트릭스 매핑 테이블입니다. 작업 성격에 맞게 최적의 모델을 분담 배치합니다.

| 작업 단계 | 핵심 요구 역량 | 추천 AI 모델 | 역할 및 활용 상세 |
| :--- | :--- | :--- | :--- |
| **Phase 1: 코드 정밀 분석 & 버그 상세 설계** | 복잡한 시퀀스 전이 추적, 포인터 오염 분석 | **Gemini 1.5 Pro** | 다중 파일 간의 논리 흐름을 긴 컨텍스트로 전체 조망하고 설계 무결성 보장 |
| **Phase 2: 레거시 코드 일괄 매핑 제거** | 반복적인 매핑 코드 삭제 및 안전성 확보 | **Gemini 1.5 Flash** | 빠른 토큰 처리 속도로 공용 팩토리 파일 등에서 일괄 제거 및 안전한 삭제 범위 지정 |
| **Phase 3: 오케스트레이터 전이 버그 수정** | 상태 머신 리턴값 정정, 오염 방지 로직 개발 | **Gemini 1.5 Pro** | 고수준 추론을 활용하여 MQL5 환경에서의 상태 머신 세부 버그 수정 및 예외 복구 구현 |
| **Phase 4: 폴더 리팩토링 & include 파일 경로 조정** | 70개 이상의 파일 경로 재조정, 구조화 스크립트 작성 | **Gemini 1.5 Flash** | 단순 리팩토링 및 파일 이동으로 인한 무수한 `#include` 경로 재정렬 자동화 처리 |
| **Phase 5: cags/bags 스크립트 빌드 및 검증** | 컴파일 에러 디버깅, 로그 패턴 대조 분석 | **Gemini 1.5 Flash** | 신속한 빌드 에러 모니터링 및 정규식 기반 오류 파싱 피드백 수행 |
