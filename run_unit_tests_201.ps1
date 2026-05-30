# AGS Unit Test Suite Runner (run_unit_tests_201.ps1)
# Usage: powershell -File ./run_unit_tests_201.ps1

$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"

function Kill-Terminal {
    Write-Host "Ensuring terminal64 is terminated..." -ForegroundColor Gray
    Get-Process -Name "terminal64" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Clear-ResultFile {
    param([string]$path)
    if (Test-Path -Path $path) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
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

Write-Host "=================================================="
Write-Host "AGS Unit Test Suite Runner (run_unit_tests_201.ps1)"
Write-Host "=================================================="

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

# 1. 유닛 테스트 실행 (AGSTestRunner.mq5)
Write-Host "Running Unit Test Suite (AGSTestRunner.mq5)..." -ForegroundColor Cyan

# 기존 결과 파일 제거
$unitResultPath = "$CommonPath\scenario_result.txt"
if (!(Test-Path -Path $CommonPath)) {
    New-Item -ItemType Directory -Path $CommonPath -Force | Out-Null
}
Clear-ResultFile -path $unitResultPath

# AGSTestRunner 가동을 위한 지시 파일
"UNIT_TEST" | Out-File -FilePath "$CommonPath\scenario_target.txt" -Encoding ascii -NoNewline

Write-Host "Launching unit test runner..." -ForegroundColor Gray
$unitProcess = Start-Process -FilePath $TerminalPath -ArgumentList "/config:d:\Projects\AGS\unit_startup.ini" -PassThru -NoNewWindow
if ($unitProcess -ne $null) {
    Write-Host "Unit test process started. PID: $($unitProcess.Id)" -ForegroundColor Gray
} else {
    Write-Host "ERROR: Failed to launch unit test process!" -ForegroundColor Red
    exit 1
}

# 유닛 테스트 결과 파일이 생성될 때까지 폴링 대기 (최대 40초)
$maxUnitWait = 40
$unitWaited = 0
while (!(Test-Path -Path $unitResultPath) -and ($unitWaited -lt $maxUnitWait)) {
    Start-Sleep -Seconds 1
    $unitWaited++
}
Kill-Terminal

# 결과 출력 및 성공 여부에 따라 종료 코드 반환
if (Test-Path -Path $unitResultPath) {
    $lines = Get-Content -Path $unitResultPath
    $resMap = @{}
    foreach ($line in $lines) {
        if ($line -match "^([^=]+)=(.+)$") {
            $resMap[$Matches[1]] = $Matches[2].Trim()
        }
    }
    
    Write-Host "Unit Test Summary:" -ForegroundColor Yellow
    foreach ($line in $lines) { Write-Host "  $line" -ForegroundColor Gray }
    
    if ($resMap["status"] -eq "PASSED") {
        Write-Host "Unit tests successfully completed." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "ERROR: Unit tests failed (status: $($resMap["status"]))." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERROR: Unit test result file NOT found (timeout)." -ForegroundColor Red
    exit 1
}
