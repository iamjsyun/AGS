## Cross-PC Synchronization & Modular Memory (v2.2)

## Design Documentation Standard (v1.1 - Cumulative Management)
- **PDCA/Design Storage**: 모든 설계 문서(.md)는 `_doc/` 폴더 최상위 또는 주제별 서브폴더에 저장하여 전 프로젝트가 공유한다.
- **Version Control & Naming**: 문서 파일명은 반드시 파일 이름 끝에 버전 정보를 포함해야 하며(`*_v1.x.md`), 신규 아티팩트 생성 시에도 `v1.0`부터 시작하여 명시적으로 관리한다.
- **Incremental & Faithful Updates**: 아티팩트 갱신 시 이전 버전의 핵심 내용을 충실히 유지하며, 특히 다이어그램(Mermaid 등) 및 시스템 구성도는 유실 없이 통합 관리한다. 새로운 내용은 섹션을 구분하여 하단에 추가(Append)하거나 내용을 보강하는 방식으로 누적 관리한다.
- **Internal History Mandate**: 모든 아티팩트(특히 최종 버전)는 문서 상단 또는 하단에 'Document History' 섹션을 포함하여, 이전 버전에서 변경된 핵심 사항과 이력을 파일 내부에서 즉시 확인할 수 있도록 해야 한다.
- **Korean Naming**: 아티팩트 문서명은 한국어로 작성하며, 갱신 시 버전(Ver) 정보를 접미어로 추가한다. 예: `PLAN_AGS_폴더_정비_및_빌드_복구_계획서_v1.0.md`


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

### 0. Testing Standard (v1.2)
- **Standard Symbol**: 모든 테스트(Unit, Scenario, Backtest) 및 개발 시 기본 심볼은 반드시 `GOLD#`을 사용한다.
- **Test Credentials**: 테스트용 계정 정보는 `Login: 315136196`, `Password: xmDemo@2025`를 표준으로 사용한다.
- **Login Preservation**: 테스트 시작 전 터미널의 기존 로긴 정보를 반드시 백업하고, 테스트 완료 후 백업된 데이터로 로긴 정보를 원복하여 사용자의 기존 환경을 보호해야 한다.
- **Auto-Trading**: 터미널 실행 시 항상 `/experts:on` 옵션을 포함하여 자동 매매가 활성화된 상태로 테스트를 진행한다.

### 1. 전역 관리 서비스 의존성 (SSOC)
1.  **Price Management**: 모든 가격 계산(시장가, SL/TP)은 반드시 `ICXPriceManager`를 통해서만 수행한다.
2.  **Risk Management**: 로트(Lot) 및 마진 검증은 반드시 `ICXRiskManager`를 통해서만 수행한다. (Lot <= 0 또는 Lot > 50 금지)
3.  **Symbol Management**: `Point`, `Digits`, `StopsLevel` 등 심볼 속성은 반드시 `ICXSymbolManager`를 통해서만 조회한다.
4.  **Asset Management**: 터미널 실물 자산 존재 여부는 반드시 `ICXAssetManager`를 통해 확인하며, 성공 시 `ICXSignal` 모델을 즉시 동기화한다.

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

- **Language Standard**: All source code comments MUST be written in English to ensure international maintainability and clarity.

## Operational Constraints (v1.0)
- **Manual Build Mandate**: Do NOT execute any build scripts (e.g., `build_ags_main.ps1`, `check_ags_syntax.ps1`) automatically. All builds must be explicitly requested by the user.
- **Manual Test Mandate**: Do NOT execute any test runner scripts (e.g., `run_unit_tests.ps1`, `run_all_scenarios.ps1`) automatically. All test executions must be explicitly requested by the user.

## Runtime Path Standard (v1.0)
- **Database Path**: The default SQLite database is `Terminal\Common\Files\db\AGS.db`. Both MQL5 and C# applications must use this common path for data synchronization.
- **Runtime Log Path**: All runtime logs must be stored in `Terminal\Common\Files\log\`. Log files are rotated hourly in `{sid}-{yymmdd-HH}0000.log` format.
- **Cross-App Consistency**: C# applications interacting with AGS must strictly adhere to these paths to ensure seamless data and log sharing.




