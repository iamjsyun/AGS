## Cross-PC Synchronization & Modular Memory (v2.2)

## Design Documentation Standard (v1.0)
- **PDCA/Design Storage**: 모든 설계 문서(.md)는 `_doc/` 폴더 최상위 또는 주제별 서브폴더에 저장하여 전 프로젝트가 공유한다.
- **Version Control**: 문서 파일명에는 반드시 `v1.x` 형태의 버전을 포함한다.
- **File Naming**: 문서 파일명은 반드시 파일 이름 끝에 버전 정보를 포함해야 함 (`*_v1.x.md`). 예: `ANALYSIS_CODEBASE_INTEGRITY_v1.1.md`
- **Incremental Updates**: 아티팩트(설계 문서, 분석 보고서 등) 갱신 시 이전 버전의 핵심 내용을 최대한 유지하며, 새로운 내용을 하단에 추가(Append)하거나 섹션을 구분하여 누적 관리한다.


## Trading Logging Standard (v11.1 - Extended)
모든 트레이딩 함수 호출 시 다음의 로깅 프리픽스와 형식을 엄격히 준수해야 한다. 모든 로그는 시스템 로그(Experts/Global)와 개별 세션 로그(File/Remote)에 동시에 기록되어야 한다.

1.  **주문 진입 (OrderOpen)**
    - **성공 로그**: `[EXEC-ENTRY] Sending Order: [Sym:{symbol}, Type:{type}, Lot:{lot}, Price:{price}, SL:{sl}, TP:{tp}, Mkt:{marketPrice}, M:{magic}, SID:{sid}]`
    - **실패 로그**: `[EXEC-ENTRY-FAIL] Broker Code:{ret_code}({description}), SysErr:{err}. Raw: [Sym:{symbol}, Lot:{lot}, P:{price}, SL:{sl}, TP:{tp}, M:{magic}, SID:{sid}]`

2.  **주문 수정 (OrderModify)**
    - **성공 로그**: `[ORDER-MODIFY] Sending Request: [Ticket:{ticket}, M:{magic}, Price:{price}, SL:{sl}, TP:{tp}]`
    - **실패 로그**: `[ORDER-MODIFY-FAIL] Broker Code:{ret_code}({description}), SysErr:{err}. Raw: [Ticket:{ticket}, M:{magic}, Price:{price}, SL:{sl}, TP:{tp}]`

3.  **포지션 수정 (PositionModify)**
    - **성공 로그**: `[POS-MODIFY] Sending Request: [Ticket:{ticket}, M:{magic}, SL:{sl}, TP:{tp}]`
    - **실패 로그**: `[POS-MODIFY-FAIL] Broker Code:{ret_code}({description}), SysErr:{err}. Raw: [Ticket:{ticket}, M:{magic}, SL:{sl}, TP:{tp}]`

4.  **주문 삭제 (OrderDelete)**
    - **성공 로그**: `[ORDER-DELETE] Sending Request: [Ticket:{ticket}, M:{magic}]`
    - **실패 로그**: `[ORDER-DELETE-FAIL] Broker Code:{ret_code}({description}), SysErr:{err}. Raw: [Ticket:{ticket}, M:{magic}]`

## Trading Process Standard (v11.3 - Mandatory)
모든 트레이딩 신호 처리 및 감시 작업은 다음의 **SSOC(Single Source of Calculation)** 원칙을 엄격히 준수해야 한다.

### 1. 전역 관리 서비스 의존성 (SSOC)
1.  **Price Management**: 모든 가격 계산(시장가, SL/TP)은 반드시 `ICXPriceManager`를 통해서만 수행한다.
2.  **Risk Management**: 로트(Lot) 및 마진 검증은 반드시 `ICXRiskManager`를 통해서만 수행한다. (Lot <= 0 또는 Lot > 50 금지)
3.  **Symbol Management**: `Point`, `Digits`, `StopsLevel` 등 심볼 속성은 반드시 `ICXSymbolManager`를 통해서만 조회한다.
4.  **Inventory Management**: 터미널 실물 자산 존재 여부는 반드시 `ICXInventoryManager`를 통해 확인하며, 성공 시 `ICXSignal` 모델을 즉시 동기화한다.

### 2. 신호 처리 및 보정 규칙
1.  **신호가 무시**: 신호에 주입된 원본 가격(`price_signal`)은 무시하고 실시간 시장가 기준 `execPrice`를 산출한다.
2.  **시장가 역전 보정**: 지정가가 시장가를 역전할 경우 자동으로 시장가 보정하여 `10015` 에러를 원천 차단한다.
3.  **포인트 기반 변환**: 가격과 로트를 제외한 모든 옵션(SL, TP, TE, TS)은 정수 포인트값으로 취급하며, 계산 시에만 가격으로 변환한다.

### 4. Loop Stability & Atomic Batch Delete Mandate (v11.4 - Critical)
모든 리스트(CArrayObj 등) 순회 및 객체 처리 시 다음 규격을 엄격히 준수한다.

1.  **Index Manipulation Prohibition**: 루프 내부에서 `Detach()`, `i--`, `total--` 등 리스트의 크기나 인덱스를 동적으로 변경하는 모든 행위를 **절대 금지**한다.
2.  **Stable Task Queue**: 루프는 고정된 크기의 작업 큐로 간주하며, 순방향(`0 -> Total`) 순회를 원칙으로 한다.
3.  **Atomic Batch Delete**: 객체의 개별 삭제(`SAFE_DELETE(sig)`)는 루프 내에서 수행하지 않는다. 루프 완료 후 리스트 자체를 삭제(`SAFE_DELETE(list)`)하거나 일괄 해제(`Clear()`) 함으로써 메모리 관리의 원자성을 보장한다.
4.  **Dangling Pointer Protection**: 루프 종료 직후 반드시 `xp.SetSignal(NULL)` 및 관련 컨텍스트 레지스트리를 정리하여 허상 포인터 발생을 차단한다.

## Architectural Mandates
- **ID Governance**: All SID/GID generation must delegate to `XIdManager` (v8.2 Standard).
    - **SID Format**: `CNO(4)-YYMMDDHH(8)-SNO(2)-GNO(2)-DIR(1)-TYPE(1)` (Total 23 chars, including hyphens).
    - **GID Format**: `CNO(4)-YYMMDDHH(8)-SNO(2)-GNO(2)` (Total 19 chars).
- **Communication Protocol**: Follow the v7.9 Archival Protocol (`xa_exit=3` for transfer).
- **>= Evaluation Mandate (v11.11)**: While '=' is used for assignment, ALL logical evaluations involving Trailing parameters (ESTART, ESTEP, ELIMIT, SSTART, SSTEP) MUST use the `>=` operator to ensure inclusive and robust execution.
- **DataManager State Transition Matrix (v9.8.11)**:
    - **신규 주입 (Save)**: `xa_entry=1`, `xa_exit=0`, `xe_status=0 (READY)`
    - **청산 요청 (Exit)**: `xa_exit=1 (ACTIVE)`
    - **청산 완료 (Comp)**: `xa_exit=2 (COMP)`, `xe_status=20 (CLOSED)`
    - **수동 청산 패스트 트랙 (Manual-Close Fast-Track)**: 터미널 수동 종료 감지 시, ATSE가 직권으로 `xe_status=24` 및 `xa_exit=2`를 동시 마킹하여 즉시 종료 확정.
    - **이관 대기 (Arch)**: `xa_exit=3 (ARCH)`
    - **상세 실행 상태 (xe_status)**: 0(READY), 1(PENDING_REQ), 2(IN_TRANSIT), 5(PENDING_PLACED), 10(EXECUTED), 20(CLOSED_SIGNAL), 21(CLOSED_SL), 22(CLOSED_TP), 99(ERROR)


## Build Environment (MQL5)
- **Compiler Path**: `D:\Program Files\XM Global MT5\MetaEditor64.exe` (Primary).
- **Automated Build**: `AGS\build.ps1` 스크립트를 사용하여 MQL5 코드를 빌드한다.
- **Build Logs**: 빌드 결과는 `_log/` 디렉토리에 타임스탬프와 함께 저장되며, UTF-16 인코딩을 준수한다.

## Caveman Execution Setting Rules (v1.0)
- **Execution Mode**: All trading operations must operate in "Caveman" mode, ensuring minimal dependency on external libraries and maximum reliance on explicit, low-level MQL5 code.
- **Safety Protocol**: Every transaction must include an explicit safety guard and confirmation check before execution.
- **Resource Management**: Strictly manage all memory and handles; no automatic resource cleanup is permitted without explicit validation.

## Testing & Verification Standard (v1.0)
- **Execution Policy**: 모든 테스트 스크립트(Unit Tests, E2E Scenarios 등)는 개발자의 임의 실행을 금지하며, 오직 사용자의 명시적인 실행 요청이 있을 때에만 실행한다.

