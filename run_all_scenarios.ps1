# AGS All Scenarios Runner (run_all_scenarios.ps1)
# Usage: powershell -File ./run_all_scenarios.ps1

$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"
$WorkspaceScripts = "d:\Projects\AGS\MT5\_Test\Scenarios\Scripts"
$ManifestPath = "d:\Projects\AGS\MT5\_Test\Scenarios\scenario_manifest.json"
$ReportPath = "d:\Projects\AGS\_doc\result\test_results_summary.json"

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

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "AGS All Scenarios Runner (run_all_scenarios.ps1)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Sync TSDL scripts to Sandbox
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

# 2. Load Manifest
if (!(Test-Path -Path $ManifestPath)) {
    Write-Host "ERROR: Manifest file not found: $ManifestPath" -ForegroundColor Red
    exit 1
}
$manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json
$results = @()
$totalCount = 0
$passedCount = 0
$failedCount = 0

# 3. Batch loop execution
foreach ($scen in $manifest.scenarios) {
    $totalCount++
    $scenId = $scen.id
    $scenRelFile = "AGS\" + $scen.file.Replace("/", "\")
    
    Write-Host "[$totalCount/$($manifest.scenarios.Count)] Running Scenario: $scenId ($scenRelFile)" -ForegroundColor Cyan
    
    # Clean up previous targets/results
    $targetFilePath = "$CommonPath\scenario_target.txt"
    $resultFilePath = "$CommonPath\scenario_result.txt"
    if (Test-Path -Path $targetFilePath) { Remove-Item -Path $targetFilePath -Force }
    Clear-ResultFile -path $resultFilePath
    
    # Write target scenario
    $scenRelFile | Out-File -FilePath $targetFilePath -Encoding ascii -NoNewline
    
    # Launch terminal
    Write-Host " Relaunching terminal with runner_startup.ini..." -ForegroundColor Gray
    $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:d:\Projects\AGS\runner_startup.ini" -PassThru -NoNewWindow
    if ($process -ne $null) {
        Write-Host " Terminal process started successfully. PID: $($process.Id)" -ForegroundColor Gray
    } else {
        Write-Host " ERROR: Start-Process returned null for scenario!" -ForegroundColor Red
    }
    
    # Wait for completion (Up to 40 seconds)
    $maxWait = 40
    $waited = 0
    while (!(Test-Path -Path $resultFilePath) -and ($waited -lt $maxWait)) {
        Start-Sleep -Seconds 1
        $waited++
    }
    
    # Force close terminal
    Kill-Terminal
    
    # Gather results
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

# 4. Save Integrated Report JSON
$summary = [PSCustomObject]@{
    timestamp   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    total_run   = $totalCount
    passed      = $passedCount
    failed      = $failedCount
    success_rate = "$([Math]::Round(($passedCount / $totalCount) * 100, 2))%"
    results     = $results
}

$logFolder = Split-Path -Path $ReportPath
if (!(Test-Path -Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder -Force | Out-Null }

$summary | ConvertTo-Json -Depth 4 | Out-File -FilePath $ReportPath -Encoding utf8
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Batch scenario E2E run finished." -ForegroundColor Green
Write-Host "Passed: $passedCount, Failed: $failedCount" -ForegroundColor Green
Write-Host "Report saved to: $ReportPath" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

if ($failedCount -eq 0) {
    exit 0
} else {
    exit 1
}
