# [Design] AGS 통합 로그 출력 형식 정의 설계서 (v1.1)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-30 | Initial Integrated Logging Format (UAF & Trading Standard Consolidation) | Antigravity |
| v1.1 | 2026-05-30 | Refined payloader structure, explicit price translation (TE/TS/SL/TP), and remote XML (log4net) protocol mandate. | Antigravity |

---

## 1. 개요 및 목적 (Overview & Goals)

본 설계서는 AGS (Active Trading Session Engine)의 기존 로그 출력 구조를 그대로 유지하는 상태에서, 로그 메시지의 내부 **페이로더(Payloader) 세부 형식**과 **원격 소켓 전송 프로토콜(XML)** 규격을 정밀 보완하기 위해 작성되었습니다.

오류나 상태가 기록될 때 원인 파악에 필수적인 자산 및 설정 데이터가 누락되는 현상을 방지하고, 원격 모니터링 시스템(예: Log4View 등)과의 호환성을 위해 XML 통신 규격을 강제합니다.

### 핵심 설계 개정 사항
1. **기존 구조 유지**: `CXLogDispatcher`, `CXFileLogger`, `CXRemoteLogger`, `CXDbLogger`로 흐르는 기본 라우팅 체계 및 동적 스위칭 구조는 보존.
2. **원격 전송 프로토콜 규격 (XML Mandate)**: 원격 소켓 로그 전송 시, 표준 로그 텍스트 외에 **log4net XML event** 포맷 프로토콜을 필히 준수하여 전송.
3. **페이로더(Payloader) 강제 통합**: 모든 로그라인에는 단순히 상태/오류 문구만 기록하는 것을 금지하며, 해당 상태를 발생시킨 핵심 파라미터 컨텍스트(Payloader)를 상시 결합하여 출력.
4. **포인트의 가격 변환 표시**: 포인트 단위로 관리되는 트레일링 및 주문 매개변수(TE, TS, SL, TP)를 실시간 호가/시작가를 기준으로 계산한 **물리적 가격(Price) 단위로 자동 변환**하여 함께 표시.

---

## 2. 통합 로그 라인 메시지 포맷 (AGS Log Format)

AGS 엔진 내부 및 파일 로거에 기록되는 로그 라인의 본체는 다음과 같은 구조를 지닙니다:

```text
[TIMESTAMP] [LEVEL] [PRODUCER] [PAYLOAD] [PHASE/ACTION] Message {Error/Trace Context}
```

### 2.1. 세부 헤더 필드
* **LEVEL (로그 레벨)**: `[DEBUG]`, `[INFO]`, `[WARN]`, `[ERROR]`, `[FATAL]`
* **PRODUCER (메시지 생산자)**: 로그를 생성한 컴포넌트의 클래스 또는 함수 명칭. (예: `CXOrderManager`, `CXTaskTrail_R_Execute`, `CXIntegrityGuard` 등)

### 2.2. 공통 페이로더 정보 (PAYLOAD)
모든 로그에 공통으로 포함되는 트레이딩 핵심 컨텍스트 정보입니다.
```text
[SID:{sid}, Lot:{lot}, TE:{te_start}pt({te_start_price}), TS:{ts_start}pt({ts_start_price}), SL:{sl}pt({sl_price}), TP:{tp}pt({tp_price})]
```
* **SID**: 대상 거래 세션 식별 ID
* **Lot**: 주문 계약 수량
* **TE / TS / SL / TP 포인트-가격 변환 표시**:
  - `te_start` / `ts_start` / `sl` / `tp`는 정수 포인트값(`pt`)으로 먼저 표시합니다.
  - 뒤이어 괄호 내부에 **실시간 시장가(Ask/Bid) 또는 주문 시작가 기준 계산된 물리적 실제 가격**을 표기합니다.

> [!IMPORTANT]
> **포인트 대 가격 변환식**:
> * $\text{Direction} = \text{BUY}$ 일 때:
>   $$\text{Price} = \text{Market Bid} - (\text{Points} \times \text{Point Value})$$
> * $\text{Direction} = \text{SELL}$ 일 때:
>   $$\text{Price} = \text{Market Ask} + (\text{Points} \times \text{Point Value})$$

### 2.3. 가변적 오류 및 추적 로그 데이터 (Error/Trace Context)
오류 발생 시 단순히 `Failed to open order`와 같은 단순 메시지 외에 아래의 구조화된 상세 예외 필드를 결합하여 출력해야 합니다.
```text
{ErrCode: {code}, ErrMsg: "{message}", LastState: "{state}", Symbol: "{symbol}"}
```

---

## 3. 원격 로그 XML 프로토콜 규격 (Remote XML Protocol Mandate)

`CXRemoteLogger`를 통해 TCP 소켓으로 외부 수집기에 전송되는 로그는 반드시 아래 **log4net XML Schema** 프로토콜에 맞추어 마샬링된 후 UTF-8 바이트 스트림으로 송신되어야 합니다.

### 3.1. XML 프로토콜 형식
```xml
<log4net:event logger="AGS" timestamp="YYYY.MM.DD HH:MM:SS" level="LEVEL" thread="1">
  <log4net:message><![CDATA[[LEVEL] [PRODUCER] [PAYLOAD] message]]></log4net:message>
  <log4net:properties>
    <log4net:data name="sid" value="CNO(4)-YYMMDDHH(8)-SNO(2)-GNO(2)-DIR(1)-TYPE(1)" />
    <log4net:data name="producer" value="PRODUCER_NAME" />
    <log4net:data name="lot" value="LOT_SIZE" />
    <log4net:data name="te_price" value="TE_CONVERTED_PRICE" />
    <log4net:data name="ts_price" value="TS_CONVERTED_PRICE" />
    <log4net:data name="sl_price" value="SL_CONVERTED_PRICE" />
    <log4net:data name="tp_price" value="TP_CONVERTED_PRICE" />
  </log4net:properties>
</log4net:event>
```

* `<log4net:message>` 요소 내부에는 파싱기와의 호환성 및 CDATA 손상 방지를 위해 대괄호 구조를 유지한 원본 텍스트를 감싸서 주입합니다.
* `<log4net:properties>`를 통해 `sid`, `producer` 및 가격 변환이 반영된 개별 페이로드 요소를 외부 대시보드(Log4View 등)에서 즉시 필터링할 수 있도록 속성 키로 매핑합니다.

---

## 4. 로그 작성 규칙 시나리오 (Usage Scenario)

### 4.1. 일반 상태 변동 로그 예시 (INFO)
* **상황**: Trailing Stop이 발동되어 트래킹 시작 단계
* **출력 로그**:
  ```text
  [2026.05.30 21:08:46.120] [INFO] [CXTaskTrail_V_Activate] [SID:CNO1-26053021-01-01-0-1, Lot:0.50, TE:20pt(1945.20), TS:30pt(1942.10), SL:150pt(1939.00), TP:300pt(1984.00)] [ACTIVE-TRAIL] Trailing stop activation threshold reached.
  ```

### 4.2. 오류 발생 로그 예시 (ERROR) - 페이로더 필수 포함 규격
* **상황**: 손절매(SL) 가격 수정 요청 중 브로커로부터 10016(Invalid SL/TP) 코드 응답
* **출력 로그**:
  ```text
  [2026.05.30 21:09:12.450] [ERROR] [CXPositionManager] [SID:CNO1-26053021-01-01-0-1, Lot:0.50, TE:20pt(1945.20), TS:30pt(1942.10), SL:150pt(1939.00), TP:300pt(1984.00)] [POS-MODIFY-FAIL] Broker Code:10016(Invalid Stops), SysErr:0. Raw: [Ticket:482091, M:1001] {ErrCode: 10016, ErrMsg: "Invalid Stops Level", TargetSL: 1939.00, CurrentBid: 1939.10}
  ```

> [!CAUTION]
> 로그 작성 시 페이로더 블록(`[SID:..., Lot:...]`)을 임의로 생략하고 텍스트 메시지만 기재하는 행위는 **규격 위반**으로 컴파일 검증 및 정적 무결성 테스트 단계에서 걸러지도록 엄격하게 규제합니다.

---

## 5. 기존 MQL5 모듈의 연계 수정 방향

1. **`CXAuditFormatter::Build` 함수 변경**:
   * 기본적으로 모든 로그 생산용 스트링 빌더는 이 Formatter를 경유하도록 확장합니다.
   * `specData` 인수에 오류 데이터(`ErrCode`, `ErrMsg` 등)가 주입되었을 때, 괄호 뒤에 딕셔너리 구조`{...}`로 동적 통합하여 최종 문자열을 반환하도록 리팩토링합니다.
2. **`CXRemoteLogger::Log` 수정**:
   * 전송할 데이터가 주입되면 XML 조립 시 `m_sid` 외에 `m_producer` 및 전달받은 메시지 본문에서 추출된 `te_price`, `ts_price`, `sl_price`, `tp_price` 구조를 파싱/매핑하여 전송 버퍼에 탑재하도록 개선합니다.
