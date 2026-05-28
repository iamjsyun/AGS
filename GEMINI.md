<!-- Import: C:\Users\hsnote\.gemini\extensions\oh-my-gemini-cli\GEMINI.md -->
## Cross-PC Synchronization & Modular Memory (v2.2)
- **Log Initialization Mandate (v11.5 - Critical)**: 모든 EA(ATSE) 및 App(ATSA) 기동 시 기존 로그 파일을 **반드시 초기화(Truncate)** 해야 한다. 이전 가동 기록은 삭제하거나 새로운 파일로 교체하여 데이터의 신선함을 유지한다.
- **System Log Mirroring**: 모든 파일 로그 기록 시, 터미널의 시스템 로그(Experts Tab)에도 동일한 메시지가 **반드시 출력(Print)** 되어야 한다. 로그 파일과 시스템 로그 간의 메세지 불일치를 엄격히 금지한다.
- **Symbolic Link Mandate (Recommended)**: To ensure real-time synchronization of **Global Memory** and **Settings**, run the following in Administrator PowerShell:
  ```powershell
  Remove-Item -Path "$env:USERPROFILE\.gemini" -Recurse -Force
  New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.gemini" -Target "G:\내 드라이브\_Doc\gemini"
  ```
- **Project Memory Redirection (Fallback)**: If Admin rights are unavailable, all **Private Project Memory (Tier 3)** MUST be manually saved in `_doc/gemini/memory/ats/` (Cloud Linked) to ensure cross-PC consistency.
- **Custom Commands**: Project-wide CLI shortcuts are stored in `_doc/gemini/commands/`.

## Design Documentation Standard (v1.0)
- **PDCA/Design Storage**: 모든 설계 문서(.md)는 `_doc/` 폴더 최상위 또는 주제별 서브폴더에 저장하여 전 프로젝트가 공유한다.
- **Version Control**: 문서 파일명에는 반드시 `v1.x` 형태의 버전을 포함한다.

## Simulator Shared Memory
- **Simulator Target**: ATSE의 하이퍼-원자적 태스크 무결성 검증.
- **Core Principle**: Step-Lock 기반 Virtual Clock 시스템 (결정성 보장).
- **Data Source**: SQLite 역주입 및 CSV 시나리오 연동.

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

## DataManager UI/UX Standards (v8.8 - Critical)
- **XAML Binding Convention**: All editor fields in `DataManagerView.xaml` MUST use lowercase property names matching the `XSignal` model (e.g., `cno`, `sno`, `symbol`, `lot`, `tp`, `sl`). Do NOT use PascalCase for these bindings.
- **Initialization Sequence**: `DataManagerViewModel` must explicitly set model fields to the 0th index of available lists (CnoList, SnoList, etc.) during construction or reset.
- UI Synchronization: After any batch update to `SelectedSignal`, `RefreshAll()` (which triggers `RaisePropertyChanged(null)`) must be called to force WPF to re-read all bound values.
- **Persistence**: These rules ensure ComboBoxes default to index 0 on startup and preserve selections during "New Signal" operations.

## WPF Navigation Standards (v9.0)
- **Pattern**: All primary UI navigation MUST use **Dynamic View Switching (View-Model First)**.
- **Mechanism**: Transitions are handled by swapping the `CurrentView` property in `MainViewModel`.
- **Rendering**: `MainWindow.xaml` uses `DataTemplate` definitions in its Resources to map ViewModel types to their corresponding UserControl Views.
- **Prohibition**: Do NOT use standalone popup windows (`Window.Show()`) for main application features (Dashboard, DataManager, Settings). All such features must be implemented as `UserControl` Views integrated into the main frame.

## Configuration Management (v9.0)
- **Centralized Source**: All system, engine, and channel settings MUST reside in `_config\ATSA.json`. (Redundant sections like `SystemSettings` are integrated into `System`).
- **Custom Configuration Path**: The system supports specifying a custom configuration file path via the `-config` command-line argument (e.g., `ATSA.exe -config C:\Path\To\MyConfig.json`).
- **Prohibition**: Redundant configuration files (e.g., `XConfig.json`) are strictly prohibited.
- **Explicit Full-Path Mandate**: The `DatabaseFullPath` property in `ATSA.json` SHOULD contain the absolute path to the MetaTrader 5 Common Files folder for maximum visibility.
- **Auto-Generation**: The system automatically generates `ATSA.json` with the current user's MT5 common path if missing.
- **Reference Standard**: All modules MUST use `XConfig.GetConfigPath()` to access the unified settings.

## Build Environment (MQL5)
- **Compiler Path**: `D:\Program Files\XM Global MT5\MetaEditor64.exe` (Primary).
- **Automated Build**: `ATSE\build.ps1` 스크립트를 사용하여 MQL5 코드를 빌드한다.
- **Build Logs**: 빌드 결과는 `_log/` 디렉토리에 타임스탬프와 함께 저장되며, UTF-16 인코딩을 준수한다.

## UCXSignalView UI Standard (v9.6)
- **Layout Architecture**: Strictly follow a **Two-Line Card-Hybrid** design.
- **Directional Marker**: Far-left 4px vertical line indicates direction (BUY: `#2196F3` Blue, SELL: `#F44336` Red).
- **Line 1 (Trading Data)**: SID, Symbol, Dir, Type, Price, LotT, Lot, TE, TS, SL, TP, XA:EN, XA:EX.
- **Line 2 (Execution Details)**: Status Badge (`Code:Name`) + `┗` Link + Full-width `xe_status_msg`.
- **Numeric Formatting**:
    - `price`, `lot`: Standardized to `0.00` (N2 format).
    - `te_start`, `ts_start`, `sl`, `tp`: Standardized to **Integer** (N0 format).
    - All numeric fields MUST be **Right-Aligned** with a small right margin (4-6px).
- **Descriptive Displays**: `Dir`, `LotT`, `XA:EN`, `XA:EX`, and `Status` MUST show the combined "Code:Name" format (e.g., `10:EXECUTED`).
- **Aesthetics**: Each row is an independent card with subtle margins, `CornerRadius="3"`, and no grid lines.
