# AGS Batch Scenario Tester (run_single_scenario_102.ps1)
# Usage: powershell -File ./run_single_scenario_102.ps1

$TerminalPath = "D:\Program Files\XM Global MT5\terminal64.exe"
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"
$WorkspaceScripts = "d:\Projects\AGS\MT5\_Test\Scenarios\Scripts"
$ManifestPath = "d:\Projects\AGS\MT5\_Test\Scenarios\scenario_manifest.json"
$LogFile = "d:\Projects\AGS\_log\batch_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Kill-Terminal {
    Write-Host "Ensuring terminal64 is terminated..." -ForegroundColor Gray
    Get-Process -Name "terminal64" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Clear-ResultFile {
    param([string]$path)
    if (Test-Path -Path $path) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
    }
}

# 0. Clean up
Kill-Terminal
if (!(Test-Path "d:\Projects\AGS\_log")) { New-Item -ItemType Directory -Path "d:\Projects\AGS\_log" | Out-Null }

# 1. Load manifest
if (!(Test-Path -Path $ManifestPath)) {
    Write-Host "ERROR: Manifest file not found at $ManifestPath" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json
$scenarios = $manifest.scenarios

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "AGS Batch Scenario Tester (run_single_scenario_102.ps1)" -ForegroundColor Cyan
Write-Host "Total Scenarios: $($scenarios.Count)" -ForegroundColor Cyan
Write-Host "Log: $LogFile" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$summary = @{
    Total = $scenarios.Count
    Passed = 0
    Failed = 0
}

# 2. Sync TSDL scripts
New-Item -ItemType Directory -Path "$CommonPath\Core" -Force | Out-Null
New-Item -ItemType Directory -Path "$CommonPath\Trade" -Force | Out-Null
New-Item -ItemType Directory -Path "$CommonPath\Resilience" -Force | Out-Null
Copy-Item -Path "$WorkspaceScripts\Core\*.tsd" -Destination "$CommonPath\Core\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$WorkspaceScripts\Trade\*.tsd" -Destination "$CommonPath\Trade\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$WorkspaceScripts\Resilience\*.tsd" -Destination "$CommonPath\Resilience\" -Force -ErrorAction SilentlyContinue

# 3. Iterate Scenarios
foreach ($scen in $scenarios) {
    $scenId = $scen.id
    $scenRelFile = "AGS/" + $scen.file
    
    Write-Host "`nRunning Scenario: $scenId" -ForegroundColor Yellow
    
    # Prepare Database
    $dbDir = Split-Path -Path $CommonPath
    $TemplateDb = Join-Path -Path $dbDir -ChildPath "ats.db"
    $TargetDb = Join-Path -Path $dbDir -ChildPath "AGS.db"
    if (Test-Path -Path $TemplateDb) { Copy-Item -Path $TemplateDb -Destination $TargetDb -Force }
    
    $targetFilePath = "$CommonPath\scenario_target.txt"
    $resultFilePath = "$CommonPath\scenario_result.txt"
    Clear-ResultFile -path $resultFilePath
    $scenRelFile | Out-File -FilePath $targetFilePath -Encoding ascii -NoNewline
    
    # Launch Terminal
    $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:d:\Projects\AGS\runner_startup.ini" -PassThru -NoNewWindow
    
    # Wait
    $maxWait = 40
    $waited = 0
    while (!(Test-Path -Path $resultFilePath) -and ($waited -lt $maxWait)) {
        Start-Sleep -Seconds 1
        $waited++
    }
    Kill-Terminal
    
    # Analyze
    if (Test-Path -Path $resultFilePath) {
        $lines = Get-Content -Path $resultFilePath
        $resMap = @{}
        foreach ($line in $lines) {
            if ($line -match "^([^=]+)=(.+)$") { $resMap[$Matches[1]] = $Matches[2].Trim() }
        }
        
        $msg = "[$(Get-Date -Format 'HH:mm:ss')] ${scenId}: $($resMap['status']) (Passed: $($resMap['passed']), Failed: $($resMap['failed']))"
        if ($resMap["status"] -eq "PASSED") {
            $summary.Passed++
            Write-Host $msg -ForegroundColor Green
        } else {
            $summary.Failed++
            Write-Host $msg -ForegroundColor Red
            Add-Content -Path $LogFile -Value $msg
        }
    } else {
        $summary.Failed++
        $msg = "[$(Get-Date -Format 'HH:mm:ss')] ${scenId}: FAILED (No result file generated)"
        Write-Host $msg -ForegroundColor Red
        Add-Content -Path $LogFile -Value $msg
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "BATCH TEST COMPLETE" -ForegroundColor Cyan
$color = if ($summary.Failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "Passed: $($summary.Passed), Failed: $($summary.Failed)" -ForegroundColor $color
Write-Host "==================================================" -ForegroundColor Cyan
