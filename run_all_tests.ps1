# AGS Batch E2E Scenario Tester (run_all_tests.ps1)
# Usage: powershell -File ./run_all_tests.ps1

$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"
$WorkspaceScripts = "d:\Projects\AGS\MT5\_Test\Scenarios\Scripts"
$ManifestPath = "d:\Projects\AGS\MT5\_Test\Scenarios\scenario_manifest.json"
$ReportPath = "d:\Projects\AGS\_doc\result\test_results_summary.json"

function Kill-Terminal {
    Write-Host "Ensuring terminal64 is terminated..." -ForegroundColor Gray
    Get-Process -Name "terminal64" -ErrorAction SilentlyContinue | Stop-Process -Force
    # 포트, 메모리, 파일 락 해제를 위한 충분한 안정화 대기 시간 (3초)
    Start-Sleep -Seconds 3
}

function Clear-ResultFile {
    param([string]$path)
    if (Test-Path -Path $path) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        # 파일 시스템 삭제 반영을 강하게 보장 (최대 3초)
        $limit = 30
        while ((Test-Path -Path $path) -and ($limit -gt 0)) {
            Start-Sleep -Milliseconds 100
            Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            $limit--
        }
    }
}

# 0. Clean up existing terminal instances before run
Kill-Terminal

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "AGS Batch E2E Scenario Tester (run_all_tests.ps1)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. 시나리오 스크립트 파일 동기화 (Workspace -> Sandbox)
Write-Host "Syncing TSDL scripts to Sandbox..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$CommonPath\Core" -Force | Out-Null
New-Item -ItemType Directory -Path "$CommonPath\Trade" -Force | Out-Null
New-Item -ItemType Directory -Path "$CommonPath\Resilience" -Force | Out-Null

Copy-Item -Path "$WorkspaceScripts\Core\*.tsd" -Destination "$CommonPath\Core\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$WorkspaceScripts\Trade\*.tsd" -Destination "$CommonPath\Trade\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$WorkspaceScripts\Resilience\*.tsd" -Destination "$CommonPath\Resilience\" -Force -ErrorAction SilentlyContinue
Write-Host "TSDL script sync complete." -ForegroundColor Green

# Prepare Database
$dbDir = Split-Path -Path $CommonPath
$TemplateDb = Join-Path -Path $dbDir -ChildPath "ats.db"
$TargetDb = Join-Path -Path $dbDir -ChildPath "AGS.db"
if (Test-Path -Path $TemplateDb) {
    Copy-Item -Path $TemplateDb -Destination $TargetDb -Force
    Write-Host "Database AGS.db prepared from template." -ForegroundColor Green
} else {
    Write-Host "WARNING: Template database ats.db NOT found." -ForegroundColor Yellow
}

# 1.5. 유닛 테스트 실행 (AGSTestRunner.mq5)
Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "Running Unit Test Suite (AGSTestRunner.mq5)..." -ForegroundColor Cyan

# 기존 결과 파일 제거
$unitResultPath = "$CommonPath\scenario_result.txt"
Clear-ResultFile -path $unitResultPath

# AGSTestRunner 가동을 위한 지시 파일 (AGSTestRunner는 고정되어 있으므로 target 불필요하나, 
# 만약 CXScenarioRunner.mq5가 이 지시를 따른다면 'UNIT_TEST' 지시를 내림)
"UNIT_TEST" | Out-File -FilePath "$CommonPath\scenario_target.txt" -Encoding ascii -NoNewline

Write-Host "Launching unit test runner..." -ForegroundColor Gray
$unitProcess = Start-Process -FilePath $TerminalPath -ArgumentList "/config:d:\Projects\AGS\unit_startup.ini" -PassThru -NoNewWindow
if ($unitProcess -ne $null) {
    Write-Host "Unit test process started. PID: $($unitProcess.Id)" -ForegroundColor Gray
} else {
    Write-Host "ERROR: Failed to launch unit test process!" -ForegroundColor Red
}

# 유닛 테스트 결과 파일이 생성될 때까지 폴링 대기 (최대 40초, MT5 시작~EA 완료 실측 ~22초)
$maxUnitWait = 40
$unitWaited = 0
while (!(Test-Path -Path $unitResultPath) -and ($unitWaited -lt $maxUnitWait)) {
    Start-Sleep -Seconds 1
    $unitWaited++
}
Kill-Terminal

if (Test-Path -Path $unitResultPath) {
    $unitLines = Get-Content -Path $unitResultPath
    Write-Host "Unit Test Summary:" -ForegroundColor Yellow
    foreach ($line in $unitLines) { Write-Host "  $line" -ForegroundColor Gray }
} else {
    Write-Host "WARNING: Unit test result file NOT found." -ForegroundColor Red
}
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

# 2. 매니페스트 로드
if (!(Test-Path -Path $ManifestPath)) {
    Write-Host "ERROR: Manifest file not found: $ManifestPath" -ForegroundColor Red
    exit 1
}
$manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json
$results = @()
$totalCount = 0
$passedCount = 0
$failedCount = 0

# 3. 배치 루프 실행
foreach ($scen in $manifest.scenarios) {
    $totalCount++
    $scenId = $scen.id
    $scenRelFile = "AGS\" + $scen.file.Replace("/", "\")
    
    Write-Host "[$totalCount/$($manifest.scenarios.Count)] Running Scenario: $scenId ($scenRelFile)" -ForegroundColor Cyan
    
    # 기존 결과 파일 및 타겟 지시 파일 제거
    $targetFilePath = "$CommonPath\scenario_target.txt"
    $resultFilePath = "$CommonPath\scenario_result.txt"
    if (Test-Path -Path $targetFilePath) { Remove-Item -Path $targetFilePath -Force }
    Clear-ResultFile -path $resultFilePath
    
    # 타겟 지정 쓰기
    $scenRelFile | Out-File -FilePath $targetFilePath -Encoding ascii -NoNewline
    
    # 단말 가동
    Write-Host " Relaunching terminal with runner_startup.ini..." -ForegroundColor Gray
    $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:d:\Projects\AGS\runner_startup.ini" -PassThru -NoNewWindow
    if ($process -ne $null) {
        Write-Host " Terminal process started successfully. PID: $($process.Id)" -ForegroundColor Gray
    } else {
        Write-Host " ERROR: Start-Process returned null for scenario!" -ForegroundColor Red
    }
    
    # 결과 파일이 생성될 때까지 폴링 대기 (최대 40초, MT5 시작~EA 완료 실측 ~22초)
    $maxWait = 40
    $waited = 0
    while (!(Test-Path -Path $resultFilePath) -and ($waited -lt $maxWait)) {
        Start-Sleep -Seconds 1
        $waited++
    }
    
    # 단말 강제 종료
    Kill-Terminal
    
    # 결과 파일 수집 (최대 3초 대기하며 폴링)
    $scenResult = [PSCustomObject]@{
        id = $scenId
        file = $scen.file
        status = "FAILED"
        ticks = 0
        passed = 0
        failed = 0
        details = "No result file generated (Terminal execution timeout)"
    }
    
    for ($i = 0; $i -lt 3; $i++) {
        if (Test-Path -Path $resultFilePath) {
            $lines = Get-Content -Path $resultFilePath
            $resMap = @{}
            foreach ($line in $lines) {
                if ($line -match "^([^=]+)=(.+)$") {
                    $resMap[$Matches[1]] = $Matches[2].Trim()
                }
            }
            $scenResult.status = $resMap["status"]
            $scenResult.ticks = [int]$resMap["ticks"]
            $scenResult.passed = [int]$resMap["passed"]
            $scenResult.failed = [int]$resMap["failed"]
            $scenResult.details = "E2E ticks execution verification completed."
            break
        }
        Start-Sleep -Seconds 1
    }
    
    if ($scenResult.status -eq "PASSED") {
        $passedCount++
        Write-Host "  -> RESULT: PASSED (ticks: $($scenResult.ticks), passed: $($scenResult.passed))" -ForegroundColor Green
    } else {
        $failedCount++
        Write-Host "  -> RESULT: FAILED (failed: $($scenResult.failed), details: $($scenResult.details))" -ForegroundColor Red
    }
    
    $results += $scenResult
}

# 4. 통합 리포트 JSON 출력
$summary = [PSCustomObject]@{
    timestamp   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    total_run   = $totalCount
    passed      = $passedCount
    failed      = $failedCount
    success_rate = "$([Math]::Round(($passedCount / $totalCount) * 100, 2))%"
    results     = $results
}

# Ensure log folder exists
$logFolder = Split-Path -Path $ReportPath
if (!(Test-Path -Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder -Force | Out-Null }

$summary | ConvertTo-Json -Depth 4 | Out-File -FilePath $ReportPath -Encoding utf8
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Batch scenario E2E run finished." -ForegroundColor Green
Write-Host "Passed: $passedCount, Failed: $failedCount" -ForegroundColor Green
Write-Host "Report saved to: $ReportPath" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
