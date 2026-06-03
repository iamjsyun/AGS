# REPORT_AGS_현재_CXUI_및_추적_진입_알고리즘_분석_보고서_v1.3.md

## Document History
- **v1.3** (2026-06-03) 사용자 피드백 반영 (상태 배지 출력 문자열 변경: 오더 접수 -> Order, 진입 트리거 ON -> Order-TRL, 포지션 진입 -> Position, 익트 트리거 ON -> Position-TRL)
- **v1.2** (2026-06-03) 사용자 피드백 반영 (슬롯 인스턴스 수 10개에서 12개로 상향 조정, 최상단 헤더 줄에 "AGS Ver:{Build version}" 및 흰색 색상 clrWhite 표시 사양 추가)
- **v1.1** (2026-06-03) 사용자 피드백 반영 (포지션 상태 ENT/SIG/TP 상세 사양 정정, 대기 상태 LIMIT/ESTART 의미 정합성 보완) 및 파일 버전 업
- **v1.0** (2026-06-03) 현재 구현된 CXUI 차트 출력 사양, 대기 주문 최적화 시퀀스(ORD_TRACKING), 개별 트레일링 진입(TE) 태스크 상세 동작 흐름 및 아키텍처 비즈니스 목표 분석 보고서 초안 작성

---

## 1. 개요
본 보고서는 AGS(Anti-Gravity System) MQL5 엔진에 기구현되어 동작 중인 차트 시각화 레이어(CXUI)와 추적 진입(Trailing Entry, TE) 시퀀스 및 개별 태스크들의 세부 구현 상태를 정밀 분석하여 기술합니다. 이를 통해 시스템이 지향하는 기댓값 극대화와 비즈니스적 무결성 목표의 달성 현황을 투명하게 입증합니다.

---

## 2. CXUI 출력 시스템 분석

차트 대시보드를 담당하는 `CXUI` 클래스는 [CXUI.mqh](file:///d:/Projects/AGS/MT5/01_Core/UI/CXUI.mqh)에 정의되어 있으며, 개별 세션의 라이프사이클 상태를 실시간으로 차트 화면에 가시화합니다.

### 2.1 아키텍처 및 렌더링 라이프사이클
- **슬롯 인스턴스**: 최대 12개의 병렬 거래 자산 세션을 표시하기 위해 고정 배열 `m_elements[12]`을 통해 리소스를 관리합니다. (기존 10개에서 12개로 상향 설계 조정)
- **물리 리소스**: 슬롯당 두 줄의 텍스트 라벨 객체(`CChartObjectLabel` 형태의 `Line1`, `Line2`)를 MT5 차트 서브윈도우가 아닌 메인 차트에 생성합니다.
- **실시간 주입 루틴**: `CXAppService::Pulse()` 내부에서 타이머 이벤트를 감지하여 **500ms(0.5초) 주기로 `Refresh()`를 트리거**합니다.
  - `CXTerminalScanner`를 통해 실물 포지션 및 대기 주문의 유무를 감지합니다.
  - 감지된 실물 자산의 티켓을 기반으로 데이터베이스 리포지토리(`IRepository`)에 바인딩된 `ICXSignal` 인스턴스를 매핑(Binding)합니다.

### 2.2 정보 포맷 사양
차트 대시보드는 최상단에 글로벌 헤더 라인을 출력한 뒤, 개별 활성 슬롯의 신호 포지션 진입 여부에 따라 분기되어 정보를 출력합니다.

#### ① 헤더 영역 (최상단 첫 줄)
- **출력 정보**: 시스템 버전 정보 `"AGS Ver:{Build version}"`를 고정 출력합니다.
- **색상 테마**: **`clrWhite` (흰색)**으로 표시하여 일반 슬롯과 구분합니다.

#### ② 개별 슬롯 공통 영역 (Line 1)
```
▶ CNO4-YYMMDDHH-SNO-GNO  50 | 5 | 20  [STATUS]
```
- `▶`: 해당 세션이 실시간 트레일링(TE/TS) 진행 상태(Active Trailing)일 때 표기되는 접두사.
- `CNO4-...`: 세션 식별 아이디(SID).
- `50 | 5 | 20`: 해당 세션에 설정된 `TEStart` (시작 조건) | `TEStep` (갱신 스텝) | `TELimit` (한도) 포인트 단위 설정값.
- `[STATUS]`: 신호의 세부 상태 정보 표시 배지. 사용자 피드백에 따라 다음과 같이 출력 문자열을 매핑합니다:
  - `Order`: 대기 오더 접수 상태 (`XE_PENDING_PLACED`)
  - `Order-TRL`: 오더 접수 후 ESTART를 터치하여 진입 트레일링(진트) 트리거 ON 상태 (`XE_ENTRY_TRAILING`)
  - `Position`: 실물 포지션 진입 상태 (`XE_EXECUTED`)
  - `Position-TRL`: 포지션 진입 후 SSTART를 터치하여 익스텐션 트레일링(익트) 트리거 ON 상태 (`XE_STOP_TRAILING`)

#### ③ 포지션 보유 상태 (Line 2 - ACTIVE)
```
 ┗━ ENT:{entry} SIG:{discovery} ADV:{diff} TP:{tp}
```
- `SIG`: 최초 신호 감지(Discovery) 시점의 시장 가격.
- `ENT`: 실제 체결된 포지션의 진입 가격 및 진입가 대비 실시간 수익(손실) 포인트 (`{포지션 진입가} {+/- 이익 포인트}`).
- `ADV`: **가격 개선폭(Advantage)**. 신호 발견가 대비 실제 체결가가 유리하게 확보된 갭을 포인트(Pips) 단위로 변환해 실시간 계산 출력. (BUY 기준: `(SIG - ENT) / point`)
- `TP`: Take Profit 설정 가격 및 진입가 대비 TP까지의 목표 포인트 (`{TP point, 포지션 진입가 + tp point}`).

#### ④ 지정가 대기 주문 상태 (Line 2 - PENDING)
```
 ┗━ LIMIT:{entry} ESTART:{start} {extreme}
```
- `LIMIT`: 신호 감지 시 시장가 + te limit 반영 가격 (실물 주문 진입 지정가).
- `ESTART`: 신호 감지 시 시장가 + te start 반영 가격. 대기 오더 접수 시 획득한 가격으로 트레일링 세션 동안 변하지 않고 고정 유지.
- `{extreme}`: 트레일링 활성화 이후 기록된 최고/최저 극점(Extreme Price) 실시간 기록값.

### 2.3 색상 관리 (Visual Feedback)
- **방향별 테마**: BUY는 포지션 진입 시 `clrDodgerBlue`(파랑), 대기 주문 상태는 `clrWheat`로 색상을 이원화합니다. SELL은 포지션 진입 시 `clrTomato`(주황), 대기 주문 상태는 `clrLightCoral`로 표기합니다.
- **경고 토글**: 트레일링 활성화 상태(`isTrailing == true`)일 때 Line 2의 텍스트 색상을 **`clrRed`(빨간색)**로 전환하여 트레이더의 시인성을 극대화합니다.

---

## 3. 추적 진입(Trailing Entry) 시퀀스 및 태스크 동작 모델

추적 진입은 개별 자산 라이프사이클의 `ORD_TRACKING` 세션 단계에서 순차 실행되며, [CXSequenceFactory.mqh](file:///d:/Projects/AGS/MT5/06_Orchestration/Workflow/CXSequenceFactory.mqh)에 DSL로 정의되어 있습니다.

```
ORD_TRACKING -> Stage_OrderOptimization
  (TASK_A_INTENT_WATCH -> TASK_T_V_ACTIVATE_TE -> TASK_T_V_EXTREMUM_TE ->
   TASK_T_L_EVALUATE_TE -> TASK_T_R_EXECUTE_TE -> TASK_P_V_SYNC -> TASK_A_V_STALE)
```

### 3.1 태스크별 상세 비즈니스 논리
1. **`TASK_A_INTENT_WATCH`** (`CXTaskIntentWatch`): 사용자 수동 정지 또는 외부 종료 명령을 스캔하여 우선 차단합니다.
2. **`TASK_T_V_ACTIVATE_TE`** ([CXTaskTrail_V_Activate.mqh](file:///d:/Projects/AGS/MT5/07_Flow/Tasks/Trailing/CXTaskTrail_V_Activate.mqh))
   - 실시간 시장 가격이 최초 감지된 신호 기준가 대비 유리한 방향으로 `TEStart` 포인트 이상 도달했는지 연산합니다.
   - 통과 시 `TE_Active_{sid}` 상태 레지스트리를 `1`로 세팅하고, DB 상태를 `XE_ENTRY_TRAILING`로 변경합니다.
   - 글로벌 컨텍스트에 시작가(`TE_StartPrice_{sid}`)와 원본 신호 기준가(`TE_BasePrice_{sid}`)를 박제하여 이후 로직의 비즈니스적 통제선으로 삼습니다.
3. **`TASK_T_V_EXTREMUM_TE`** ([CXTaskTrail_V_Extremum.mqh](file:///d:/Projects/AGS/MT5/07_Flow/Tasks/Trailing/CXTaskTrail_V_Extremum.mqh))
   - 시장 가격이 지속적으로 유리한 방향으로 진행할 때, 최소 `TEStep` 포인트 단위 이상의 추세 확장이 있을 때만 극점 가격 `TE_Extreme_{sid}`을 최저(BUY) 혹은 최고(SELL)로 갱신하여 따라갑니다.
4. **`TASK_T_L_EVALUATE_TE`** ([CXTaskTrail_L_Evaluate.mqh](file:///d:/Projects/AGS/MT5/07_Flow/Tasks/Trailing/CXTaskTrail_L_Evaluate.mqh))
   - 실시간 시장 가격이 극점(`TE_Extreme`)으로부터 불리한 방향(반등)으로 **`TEStep` 포인트 이상 되돌아섰는지** 판단합니다.
   - 조건 만족 시 진입 확정 코드(`10`)를 발행합니다.
   - **Rebound Guard**: 되돌림을 주는 시점의 가격이 원래 신호 기준가(`baseline`)와 동일하거나 나빠진 경우(가격 개선 갭이 음수가 되는 현상), 강제로 `baseline`에서 시장가 진입을 트리거하여 신호 소실을 원천 예방합니다.
5. **`TASK_T_R_EXECUTE_TE`** ([CXTaskTrail_R_Execute.mqh](file:///d:/Projects/AGS/MT5/07_Flow/Tasks/Trailing/CXTaskTrail_R_Execute.mqh))
   - 평가 태스크로부터 코드 `10`을 받으면 실행을 시작합니다.
   - 기존의 대기 주문 티켓 번호를 획득하여 브로커 서버에서 안전하게 삭제(`DeleteOrder`)합니다.
   - 신호의 유형을 `ORDER_MARKET`으로 전환한 뒤 즉시 시장가 진입 트랜잭션(`ExecuteEntry`)을 실행하여 개선된 시장가로 최종 체결을 확보합니다.
6. **`TASK_P_V_SYNC`** (`CXTaskDbSync`): 상태 변경 내역을 SQLite DB로 기록하여 C# 상위 모듈과 상태 동기화를 이룹니다.
7. **`TASK_A_V_STALE`** (`CXTaskStaleCheck`): 설정한 만료 시간을 초과한 미체결 대기 주문에 대해 세션을 폐기합니다.

---

## 4. 아키텍처 비즈니스 달성 목표

구현된 시스템은 트레이딩 실행 전반에 걸쳐 다음과 같은 수학적 및 기술적 지표 달성을 지향합니다.

1. **포지션 진입 비용 최소화 (Negative Slippage Capture)**
   - 지정가 대기 진입의 경직성을 극복하고 유리한 추세의 끝자락(극점)을 끝까지 따라가 체결함으로써 진입 평단가를 극대화합니다.
2. **신호 유실 없는 완벽한 체결 무결성 보장 (Execution Safety)**
   - Rebound Guard 및 주문 원자적 전환(Atomic Order Transition) 구조를 통해 트레일링 도중 시장이 급변하여 가격이 이탈하더라도 신호를 잃지 않고 본래 진입 의도를 지킵니다.
3. **데이터 동기화 및 모니터링 정합성 (Single Source of Truth)**
   - 500ms 주기의 실물 터미널 스캐너와 SQLite DB 간 동기화를 보장하고, 차트 HUD 상에 가격 개선 수치(`ADV`)를 실시간으로 출력함으로써 시스템 트레이더에게 명확한 분석 지표를 제공합니다.

---
*본 보고서는 GEMINI.md 규정 및 프로젝트 설계 문서 표준(Document History, 버전 기재, 한국어 명명법, `_doc` 저장 경로 규칙)을 엄격히 준수하여 기록되었습니다.*
