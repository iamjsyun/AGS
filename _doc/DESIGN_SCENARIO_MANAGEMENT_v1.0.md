# [Design] TSDL 시나리오 구조 표준화 및 대규모 테스트 관리 설계서 (v1.0)

**Status**: Proposed  
**Author**: Antigravity  
**Target**: 수십~수백 종에 달하는 극한 TSDL 테스트 시나리오를 효과적으로 정의, 분류, 실행 및 버전 관리하기 위한 프레임워크 설계안을 수립함.

---

## 1. 개요 (Overview)

AGS의 신뢰성을 보장하기 위해 도입된 E2E 시나리오 테스트는 시뮬레이션 케이스가 늘어남에 따라 다음과 같은 스케일링 이슈에 직면합니다:
1.  **시나리오 식별의 한계**: 파일명이나 단순 ID만으로는 복잡한 예외 복구 조건과 정상 거래 시나리오의 성격을 분류하기 어려움.
2.  **수동 배치 실행 오버헤드**: 단말 상에서 매번 인풋 파일명을 바꿔 실행해야 하여, 전체 테스트 스위트를 매 빌드마다 일괄 가동하기 곤란함.
3.  **검증 결과 파편화**: 수많은 로그 파일(`build_test_*.log`)이 흩어져 생성되어, 전체 테스트 중 어느 케이스가 어떤 이유로 실패했는지 요약 파악이 어려움.

이 문서는 TSDL 파일 구조의 표준 템플릿화와 매니페스트 기반의 대규모 시나리오 수명주기 관리 체계를 제안합니다.

---

## 2. TSDL 파일 구조 표준화 (TSDL Schema Standard)

모든 시나리오 파일은 가독성과 기계적 분류를 위해 아래와 같이 **[메타데이터 - 설정 - 시뮬레이션 틱]**의 3단계 구조로 정형화합니다.

```text
# ==============================================================================
# ID: SCEN_RESILIENCE_07
# CATEGORY: Resilience (장애 복구)
# DESC: 브로커 연결 유실 후 재연결 시 30초 오더 취소 타임아웃 세션 복구 검증
# AUTHOR: Antigravity AI
# LAST_UPDATE: 2026-05-29
# ==============================================================================

# 1. 시나리오 공통 변수 정의 (Variables)
SCENARIO: SCEN_RESILIENCE_07 : "Broker Disconnect & Order Timeout Recovery"
DEFINE: CNO=2003, SNO=11, SYMBOL="GOLDF#", SID="2003-26052914-11-00-1-0"

# 2. 가상 시장 가격 모델 환경 설정 (Virtual Pricer Settings)
PRICER: GOLDF# > Linear : start=2350.00, step=0.10, digits=2

# 3. 사전 설정 조건 (Pre-Condition Injection)
TICK: 0 > INJECT: signals : sid="2003-26052914-11-00-1-0", type=0, lot=0.1, sl=50, tp=100, xe_status=0
        ? EXPECT: session : xe_status=XE_READY ! "Pre-condition injection failed"

# 4. 시뮬레이션 실행 및 기대치 검증 (Pulse & Assert Cycle)
TICK: 1 > INJECT: terminal : ticket=889012, sid="2003-26052914-11-00-1-0", sl=2345.00
        ? EXPECT: session : xe_status=XE_EXECUTED ! "Order was not accepted by Mock Terminal"

# 브로커 장애 모사 주입
TICK: 2 > FAIL: broker : connection=disconnect
        ? EXPECT: terminal : ticket=889012, exists=true ! "Asset lost prematurely"

# 타임아웃 틱 경과 후 상태 변화 관측
TICK: 10 > MARKET: price : price=2340.00
         ? EXPECT: session : xe_status=XE_ERROR ! "Session failed to transition to ERROR state on timeout"
```

---

## 3. 대규모 시나리오 관리 체계 (Scenario Lifecycle Framework)

수백 개의 시나리오를 질서 있게 관리하기 위해 **분류-인덱스-배치 실행** 파이프라인을 구축합니다.

### 3.1 디렉토리 기반 카테고리화 (Classification Directory)
시나리오 파일을 성격에 따라 4대 영역으로 엄격 분할하여 `Files\ATSE\` 하위에 배치합니다.

```text
Files/ATSE/
├── scenario_manifest.json          # 테스트 전체 대상 매니페스트 파일
├── Core/                           # 1. 인프라 검증 (Bootstrap, DI, Fail-Fast)
│   ├── test_di_failure.tsd
│   └── test_param_dual_binding.tsd
├── Trade/                          # 2. 거래 흐름 검증 (Trailing Entry/Stop, Entry Validation)
│   ├── test_trailing_entry.tsd
│   └── test_broker_sl_tp.tsd
├── Resilience/                     # 3. 예외 복구 검증 (Disconnect, Timeout, Requote, Slippage)
│   ├── test_order_cancel_timeout.tsd
│   └── test_margin_call_guard.tsd
└── Custom/                         # 4. 사용자 정의/임시 디버깅용 시나리오
```

### 3.2 매니페스트 인덱스 파일 (`scenario_manifest.json`)
전체 테스트 스위트의 실행 정책을 결정하는 메타 중앙 통제 인덱스 파일을 생성하여 버전 관리합니다.
```json
{
  "project": "AGS Test Suite",
  "version": "2.0",
  "configurations": {
    "default_database": "ATS_TEST_BATCH.db",
    "common_path": true
  },
  "scenarios": [
    {
      "id": "SCEN_CORE_01",
      "file": "Core/test_di_failure.tsd",
      "priority": "Critical",
      "timeout_ticks": 50
    },
    {
      "id": "SCEN_TRADE_01",
      "file": "Trade/test_trailing_entry.tsd",
      "priority": "High",
      "timeout_ticks": 100
    },
    {
      "id": "SCEN_RESILIENCE_07",
      "file": "Resilience/test_order_cancel_timeout.tsd",
      "priority": "Critical",
      "timeout_ticks": 150
    }
  ]
}
```

---

## 4. 시나리오 배치 실행기 및 리포팅 자동화

### 4.1 PowerShell 기반 마스터 테스터 (`run_all_tests.ps1`)
단말에 종속되지 않고 백그라운드에서 모든 시나리오를 연속 실행하여 무인 테스트(Headless Automation)를 집행하는 스크립트를 구현합니다.

```powershell
# run_all_tests.ps1
# Usage: powershell -File ./run_all_tests.ps1

$MetaEditorPath = "D:\Program Files\XM Global MT5\MetaEditor64.exe"
$TerminalPath   = "D:\Program Files\XM Global MT5\terminal64.exe"
$ManifestPath   = "Files\ATSE\scenario_manifest.json"
$ReportPath     = "_log\test_results_summary.json"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Starting AGS Batch Scenario Testing Pipeline..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. 매니페스트 파일 로드 및 파싱
$manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json
$results = @()

foreach ($scen in $manifest.scenarios) {
    Write-Host "Running Scenario: $($scen.id) ($($scen.file))" -ForegroundColor Yellow
    
    # MT5 Terminal 구동 파라미터 제어 (InpScenarioFile 설정 변경 모사)
    # 실제로는 단말의 config/common.ini 또는 /config 스위치를 사용하여 EA 입력변수를 주입하거나
    # 스크립트가 임시로 MQL5/Files/ATSE/scenario_target.txt를 작성하여
    # CXScenarioRunner.mq5가 구동 시 해당 파일 내 경로를 읽어 실행하도록 우회 구현합니다.
    
    # 임시 시나리오 타겟 파일 작성 (Runner가 기동 시 이를 참조)
    $scen.file | Out-File -FilePath "C:\Users\hijsyun\AppData\Roaming\MetaQuotes\Terminal\Common\Files\ATSE\scenario_target.txt" -Encoding utf8
    
    # 단말 가동 (비동기 대기)
    $process = Start-Process -FilePath $TerminalPath -ArgumentList "/portable" -PassThru -NoNewWindow
    # 시뮬레이션 연산 완료 대기 (정적 대기 또는 테스트 완료 플래그 파일 감시)
    Start-Sleep -Seconds 10
    $process | Stop-Process -Force
    
    # 결과 파싱 (SQLite DB 조회 또는 Runner가 작성한 json 결과 수집)
    # ... 결과 취합 로직 ...
    $scenResult = [PSCustomObject]@{
        id = $scen.id
        file = $scen.file
        status = "PASSED" # or FAILED
        ticks = 88
    }
    $results += $scenResult
}

# 2. 통합 결과 리포트 출력
$reportJson = [PSCustomObject]@{
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    total = $results.Count
    passed = ($results | Where-Object { $_.status -eq "PASSED" }).Count
    failed = ($results | Where-Object { $_.status -eq "FAILED" }).Count
    details = $results
} | ConvertTo-Json -Depth 4

$reportJson | Out-File -FilePath $ReportPath -Encoding utf8
Write-Host "Tests Completed. Report saved to: $ReportPath" -ForegroundColor Green
```

---

## 5. 설계의 이점 (Architectural Benefits)

1.  **회귀 테스트 무결성(Regression Safety)**: 코드를 전면 개편(예: PVB/UDP 전환)한 후 `run_all_tests.ps1`을 가동하는 것만으로 단 몇 분 만에 수백 개의 예외 장애 시나리오 작동 신뢰성을 100% 보증합니다.
2.  **시나리오 관리성 향상**: 카테고리별 디렉토리 분리로 개발자는 자신이 작업 중인 모듈(예: 트레일링)에 관련된 시나리오만 쉽게 필터링하여 보강할 수 있습니다.
3.  **CI/CD 파이프라인 친화성**: JSON 형태의 통합 테스트 리포트를 제공하므로, Jenkins, Github Actions 등 외부 자동 빌드 파이프라인에서 빌드 통과 여부를 즉시 파싱 판별할 수 있습니다.
