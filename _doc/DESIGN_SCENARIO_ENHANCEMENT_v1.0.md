# [Design] AGS 테스트 시나리오 고도화 및 검증 인프라 확장 설계서 (v1.0)

**Status**: Proposed  
**Author**: Antigravity  
**Version**: v1.0  
**Target**: TSDL 시나리오 검증력 극대화, 가상 시장 환경 현실화, 그리고 트레이딩 규격(로깅, 상태 전이 매트릭스) 준수 여부의 자동 감사를 지원하는 고도화 설계안을 수립함.

---

## 1. 개요 (Context & Objectives)

현재 AGS의 E2E 시나리오 테스트 프레임워크는 TSDL(Test Scenario Definition Language)을 통해 핵심 거래 흐름을 모사하고 있으나, 다음과 같은 검증 공백과 한계가 존재합니다:
1. **단순 검증 영역**: `xe_status`, `xa_exit`, 티켓 생존 여부(`exists`) 및 단순 손절선(`sl`)만 비교하여, 실제 이익실현 청산선(`tp`), 로트 수량(`lot`), 체결 가격(`price_open`)의 오차 및 슬리피지 방어 기동 검증이 불가능함.
2. **시장 환경 모사의 한계**: 호가 스프레드 확대(Spread Widening), 슬리피지(Slippage), 브로커 리쿼트(Requote) 및 체결 거부(`10015` 등)와 같은 가상 장애 상황을 주입할 수 없음.
3. **로깅 및 상태 무결성 검사 부재**: 트레이딩 로깅 표준(v11.1)에 의한 `[EXEC-ENTRY]`, `[ORDER-MODIFY]` 등 로그 프리픽스 및 데이터베이스 상세 실행 상태(xe_status) 전이 행렬의 적합성을 자동으로 감사하지 못함.

이 설계서는 **스프레드/슬리피지 모사 엔진**, **TSDL 검증 문법 확장**, 그리고 **DB 자동 적합성 감사(Audit) 모듈** 도입을 통한 고도화 방안을 제안합니다.

---

## 2. TSDL 문법 확장 설계 (TSDL Expectation Extension)

시나리오에서 거래 세부 속성 및 시스템 무결성을 전수 검사할 수 있도록 TSDL `EXPECT` 키워드의 비교 대상을 확장합니다.

### 2.1 확장 문법 규격
```text
# 1. 터미널 자산 상세 검증 확장 (tp, lot 검증)
? EXPECT: terminal : ticket=11111, exists=true, sl=2345.00, tp=2380.00, lot=0.10

# 2. 세션 데이터베이스 세부 정보 검증 (체결가, 에러 메시지 검증)
? EXPECT: session : price_open=2350.50, status_msg="TE Rebound: Executing Market Entry..."

# 3. 로깅 표준 준수 자동 검증 (ats_log 및 SQLite DB 감사)
? EXPECT: audit : symbol="GOLDF#", log_type="EXEC-ENTRY", count=1
```

### 2.2 파서 및 러너 매핑 설계
- `CXTsdlParser`에서 파싱된 `EXPECT` 키-값 쌍을 `VerifyExpectation` 함수에서 아래와 같이 추가 맵핑하여 대조합니다.
  - **`tp`**: `g_mockTerminal.GetPositionTP(ticket)` 또는 `GetOrderTP(ticket)` 값 대조.
  - **`lot`**: `g_mockTerminal.GetPositionVolume(ticket)` 또는 `GetOrderVolume(ticket)` 값 대조.
  - **`price_open`**: `sig.GetPriceOpen()`과 기대 체결가 대조.
  - **`status_msg`**: `sig.GetStatusMsg()`의 문자열 매칭 여부 대조.

---

## 3. 가상 시장 환경 고도화 (Advanced Virtual Pricer)

실제 외환/원자재 거래 시 발생하는 물리적 장애 현상을 `PRICER` 및 `ACTION` 스키마를 통해 가상 환경에 주입할 수 있도록 시뮬레이터를 고도화합니다.

### 3.1 호가 스프레드 동적 확대 (Spread Widening)
지표 발표 시점 등 시장 불안정기에 호가 차이가 급격히 벌어지는 현상을 주입합니다.
- **문법**: `ACTION: pricer : spread=100` (스프레드를 100포인트로 일시적 확대)
- **효과**: 가상 호가 피드가 Bid와 Ask를 벌려 전송하여, TP/SL 도달 판정을 왜곡/테스트함.

### 3.2 체결 슬리피지 주입 (Execution Slippage)
주문 요청 시점의 가격과 체결 시점의 가격 오차를 모사합니다.
- **문법**: `ACTION: broker : slippage=30` (체결 시 요청가 대비 30포인트 불리한 가격으로 강제 밀림)
- **효과**: `MockTerminalPlatform::ExecuteEntry` 처리 시 체결 가격을 왜곡 반영하여, AGS의 슬리피지 허용 범위 및 정합성 조율 루틴을 검증함.

### 3.3 브로커 체결 거부 및 에러 코드 주입 (Broker Reject Simulation)
브로커 서버가 특정 에러 코드를 반환하며 주문을 거부하는 상황을 모사합니다.
- **문법**: `ACTION: broker : reject_code=10015` (Invalid Price 에러 반환)
- **효과**: 주문 송신 태스크가 즉시 `TASK_YIELD` 되거나 에러 대응 상태로 전이되는 복구 메커니즘 검증.

---

## 4. DB 상태 전이 및 로깅 표준 적합성 감사 (Automated Compliance Audit)

매 시나리오 실행 완료 시점 또는 매 틱마다 SQLite 데이터베이스(`AGS.db`)에 기록된 이력과 상태 전이가 표준 규격을 충족하는지 자동 검증하는 **Audit Engine**을 도입합니다.

### 4.1 상태 전이 행렬 (Transition Matrix) 자동 감사 규칙
- 세션의 생명주기 동안 `xe_status` 및 `xa_exit` 값이 `GEMINI.md (v9.8.11)` 전이 행렬을 엄격히 따르는지 확인합니다.
  - `xe_status=0 (READY)` -> `xe_status=10 (EXECUTED)` -> `xe_status=20 (CLOSED_SIGNAL)`
  - 수동 종료 감지 시: `xe_status=24 (CLOSED_MANUAL)` 및 `xa_exit=2 (COMP)` 마킹 적합성 확인.

### 4.2 트레이딩 로그 표준 규격 (v11.1) 감사 규칙
`ats_log` 테이블에서 실행 로그에 아래 정규식과 키워드가 올바르게 포함되었는지 검증합니다:
- **주문 진입 성공**: `^\[EXEC-ENTRY\] Sending Order: \[Sym:.*, Type:.*, Lot:.*, Price:.*, SL:.*, TP:.*, Mkt:.*, M:.*, SID:.*\]`
- **주문 진입 실패**: `^\[EXEC-ENTRY-FAIL\] Broker Code:.*, SysErr:.*`
- **포지션 수정**: `^\[POS-MODIFY\] Sending Request: \[Ticket:.*, M:.*, SL:.*, TP:.*\]`

---

## 5. 추가 고도화 대상 핵심 시나리오 리스트

새로운 검증 프레임워크를 기반으로 작성할 핵심 회귀 방어 및 장애 복구 시나리오 세트입니다.

### 5.1 mql5.com 통계 기반 최빈 거래 에러 장애 모사 시나리오 (5대 케이스)
mql5.com 웹사이트 분석을 바탕으로, MT5 EA 실거래 시 브로커 측에서 가장 빈번히 발생하는 5가지 장애 응답 상황에 대응하는 Resilience 시나리오를 설계합니다.

1. **`SCEN_RESILIENCE_NO_MONEY_10019` (증거금 부족 예외 대응)**
   - **설명**: 주문 개시 요청 시 `TRADE_RETCODE_NO_MONEY` (10019, 잔고 부족) 에러가 반환되는 상황을 모사합니다.
   - **검증**: EA가 에러 감지 즉시 반복 루프를 중단하고, 신호 상태를 `XE_ERROR`로 전환하며 `status_msg`에 "No Money to Open Order"를 올바르게 출력하는지 확인합니다.

2. **`SCEN_RESILIENCE_STOPS_LEVEL_10016` (StopsLevel 위반 예외 대응)**
   - **설명**: 주문의 SL/TP가 브로커가 허용하는 최소 거리 제한(`StopsLevel`)을 위반하여 `TRADE_RETCODE_INVALID_STOPS` (10016) 에러를 수신하는 상황입니다.
   - **검증**: `ICXRiskManager`의 자동 보정 루틴이 이 거리를 정상적으로 감지하여 보정하거나, 브로커 차단 시 즉시 안전 상태(`XE_READY`)로 후퇴하여 무한 재시도를 방지하는지 확인합니다.

3. **`SCEN_RESILIENCE_REQUOTE_10020` (호가 변동 및 재요청)**
   - **설명**: 시장 가격이 급변하여 브로커가 `TRADE_RETCODE_PRICE_CHANGED` (10020) 또는 `TRADE_RETCODE_REQUOTE` (10004)를 반환하는 상황입니다.
   - **검증**: EA가 리쿼트 수신 즉시 현재의 최신 호가(Ask/Bid)를 다시 읽고 실행가를 갱신하여 재요청을 성공적으로 완료하는지 검증합니다.

4. **`SCEN_RESILIENCE_TRADE_DISABLED_10017` (심볼 거래 비활성화 대응)**
   - **설명**: 주말, 브로커 점검, 혹은 계정 제약으로 인해 거래가 중단된 상태에서 `TRADE_RETCODE_TRADE_DISABLED` (10017) 에러가 반환되는 상황입니다.
   - **검증**: EA가 심볼 비활성화를 인지하고 루프를 긴급 중단(Fail-Fast)하며, 해당 세션을 즉시 `XE_ERROR`로 마킹하여 무의미한 서버 통신을 방지하는지 검증합니다.

5. **`SCEN_RESILIENCE_TOO_MANY_REQUESTS_10024` (요청 빈도 초과 백오프 대응)**
   - **설명**: 서버 과부하로 인해 브로커로부터 `TRADE_RETCODE_TOO_MANY_REQUESTS` (10024, 과도한 요청)를 수신하는 상황입니다.
   - **검증**: EA가 즉시 `TASK_YIELD`를 통해 실행 지연(Dynamic Back-off Delay)을 걸고 일정 시간 대기한 후 성공적으로 재시도 체결에 이르는지 검증합니다.

---

### 5.2 추적 진입(Trailing Entry, TE) 변동성 및 뉴스 스파이크 정밀 검증 시나리오 (11대 케이스)
추적 진입 상태(`ORD_TRAILING`)에서 다양한 변동성 가격 데이터(5~10달러 폭) 및 뉴스 지표 발표 시 발생하는 대규모 가격 스파이크 하에서의 버퍼 가드 기동을 검증합니다.

#### A. Buy Trailing Entry 변동성 케이스 (3개 시나리오)
기초 가격 2350.00 대비 500pt~1000pt ($5.00~$10.00) 수준의 변동성을 가지는 데이터 피드 하에서의 동작입니다.

1. **`SCEN_TE_BUY_VOL_01` (Moderate Buy Volatility)**
   - **상황**: 가격이 2350.00에서 2348.00을 거쳐 2345.00까지 변동성 있게 하락 ($5.00 하락).
   - **검증**: 대기 주문(`Buy Limit`) 가격이 `te_limit`을 유지하며 2340.00으로 후퇴 수정 요청되고, 2346.00으로 $1.00 반등 시 체결이 유도되는지 검증.
2. **`SCEN_TE_BUY_VOL_02` (Deep Rebound Buy Volatility)**
   - **상황**: $8.00의 큰 하락폭(2350.00 -> 2342.00) 후 $2.00의 강력한 기술적 반등 발생.
   - **검증**: 누적 하락 극점을 2342.00으로 갱신 후, 반등 시점에서 시장가 진입 실행 및 `POS_MONITORING` 전이 완료 검증.
3. **`SCEN_TE_BUY_VOL_03` (Multi-Step Buy Trailing)**
   - **상황**: 가격이 $3.00, $3.00, $2.00씩 계단식으로 총 $8.00 하락하여 변동성을 그림.
   - **검증**: 각 하락 단계마다 대기 주문이 충돌 없이 유연하게 계단식으로 밀려 수정되며 최종 반등 시 안전하게 주문이 체결되는지 검증.

#### B. Sell Trailing Entry 변동성 케이스 (3개 시나리오)
기초 가격 2350.00 대비 500pt~1000pt ($5.00~$10.00) 상승 구간에서의 동작입니다.

4. **`SCEN_TE_SELL_VOL_01` (Moderate Sell Volatility)**
   - **상황**: 가격이 2350.00에서 2355.00까지 파동을 그리며 상승 ($5.00 상승).
   - **검증**: 대기 주문(`Sell Limit`) 가격이 `te_limit` 버퍼를 유지하며 2360.00으로 상향 수정되고, 하락 반전 시 정상 진입되는지 검증.
5. **`SCEN_TE_SELL_VOL_02` (Deep Rebound Sell Volatility)**
   - **상황**: $8.00의 큰 상승폭(2350.00 -> 2358.00) 후 $2.00 하락 반전.
   - **검증**: 상승 극점을 2358.00으로 기록하고 되돌림 기준(`te_step`) 돌파 시 매도 시장가 체결이 집행되는지 검증.
6. **`SCEN_TE_SELL_VOL_03` (Multi-Step Sell Trailing)**
   - **상황**: 가격이 계단식(+$3.00, +$3.00, +$4.00 = +$10.00)으로 상승하며 강한 변동성 표출.
   - **검증**: 다단계 상승 극점 추적과 `Sell Limit` 후퇴 수정 요청의 연속 안정성 검증.

#### C. 뉴스 및 지표 발표 스파이크 순간 도달 케이스 (5개 시나리오)
지표 발표 시 1틱 이내에 가격이 `te_limit`을 돌파하며 발생하는 극한 상황을 모사합니다.

7. **`SCEN_TE_BUY_SPIKE_NEWS_01` (Instant Down-Spike Fill)**
   - **상황**: 뉴스 발표로 1틱 만에 가격이 2350.00에서 2344.00으로 $6.00 순간 폭락. 2345.00에 배치된 `Buy Limit` 주문 영역을 돌파.
   - **검증**: 브로커 단에서 주문이 체결되었음을 인지하고 EA가 즉시 `POS_MONITORING` 상태로 전환되는 동기화 검증.
8. **`SCEN_TE_BUY_SPIKE_NEWS_02` (Instant Down-Spike Slippage Reject)**
   - **상황**: 동일 폭락 상황에서 슬리피지가 과도하게 발생하여 오더 체결에 실패하거나 거부당하는 현상 모사.
   - **검증**: EA가 체결 거부를 감지하고 안전하게 세션을 `XE_ERROR`로 유도하여 자산 이탈을 차단하는지 검증.
9. **`SCEN_TE_SELL_SPIKE_NEWS_03` (Instant Up-Spike Fill)**
   - **상황**: 지표 발표로 가격이 2350.00에서 2356.00으로 $6.00 순간 폭등. 2355.00의 `Sell Limit` 주문 관통.
   - **검증**: 브로커의 체결 이벤트를 수신한 즉시 물리 자산을 세션 포지션으로 바인딩 완료하는지 검증.
10. **`SCEN_TE_SELL_SPIKE_NEWS_04` (Instant Up-Spike Retreat Failure)**
    - **상황**: 지표 발표로 1틱 만에 $7.00 폭등하여 오더를 retreat(상향 수정) 하려 하나 브로커 통신 지연으로 거부당함.
    - **검증**: 오더 변경 실패 시 안전 가드가 활성화되어 세션을 롤백하거나 예외 처리를 무결하게 진행하는지 확인.
11. **`SCEN_TE_SPIKE_SHADOW_CANCEL` (Instant Spike with External Cancel)**
    - **상황**: 급작스러운 지표 발표 스파이크 틱이 감지됨과 동시에 데이터베이스에서 `xa_exit=1` 청산 명령이 강제 유입됨.
    - **검증**: EA가 즉시 대기 주문 삭제(`DeleteOrder`)를 송신하여 스파이크 체결을 물리적으로 사전 방어하는지 검증.

---

### 5.3 기존 핵심 복구 및 예외 검증 시나리오

1. **`SCEN_RESILIENCE_REQUOTE_10015` (초정밀 체결 거부 복구)**
   - **시나리오**: 주문 요청 시 `10015` 리쿼트 주입 -> EA가 실시간 가격을 추적하여 자동으로 체결 가격과 SL/TP를 역전 보정한 후 주문 재송신 성공 검증.

2. **`SCEN_TRADE_VOL_PARTIAL_FILL` (부분 체결 및 볼륨 리사이징)**
   - **시나리오**: 체결된 0.10 로트 포지션 중 0.04 로트만 부분 청산됨 -> 인벤토리 동기화 태스크가 잔존 수량 0.06 로트를 감지하여 DB 세션 데이터를 부분 청산 상태와 잔존 수량으로 리사이징 처리하는지 검증.

3. **`SCEN_RESILIENCE_DOUBLE_CLOSE` (이중 종료 레이스 컨디션)**
   - **시나리오**: 시스템이 자동 청산 주문(`Exit_R_Order`)을 송신한 틱과 동시에 사용자가 수동으로 포지션을 종료함 -> 터미널 실물 자산 소멸을 감지한 `IntentWatch`가 직권으로 세션을 즉시 `SESSION_CLOSED` 처리하고 중복 송신된 잔여 주문을 안전하게 철회(Cancel)하는지 검증.

---

## 6. 기대 효과 (Expected Outcomes)

1. **테스트 신뢰성 극대화**: 스프레드 확대 및 리쿼트 주입 기능을 통해 런타임에 발생할 수 있는 거의 모든 브로커 측 변수 상황을 무인 테스트 환경에서 100% 재현 및 방어할 수 있습니다.
2. **규격 준수 자동화**: 수동으로 확인하기 어려운 트레이딩 로깅 및 상태 전이 데이터베이스의 정합성을 매 시나리오 실행마다 자동으로 검증하여 규격 위반을 조기에 잡아냅니다.
3. **가독성 향상 및 런타임 Null Crash 예방**: TSDL 문법 확장으로 기동 전 검증 범위를 고도화하여 실제 계정 연동 시 안정성을 대폭 향상시킵니다.
