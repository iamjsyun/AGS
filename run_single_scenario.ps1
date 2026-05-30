# AGS Single Scenario Tester (run_single_scenario.ps1)
# Usage: powershell -File ./run_single_scenario.ps1 <ScenarioID or TSD File Path>
# Example: powershell -File ./run_single_scenario.ps1 SCEN_TRADE_GOLDEN_PATH
# Example: powershell -File ./run_single_scenario.ps1 Trade/test_golden_path.tsd

param(
    [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Scenario ID or TSD File Path")]
    [string]$Target
)

$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"
$WorkspaceScripts = "d:\Projects\AGS\MT5\_Test\Scenarios\Scripts"
$ManifestPath = "d:\Projects\AGS\MT5\_Test\Scenarios\scenario_manifest.json"

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

# 1. Load manifest and resolve target
if (!(Test-Path -Path $ManifestPath)) {
    Write-Host "ERROR: Manifest file not found at $ManifestPath" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json
$selectedScenario = $null

# Try to match by Scenario ID
$selectedScenario = $manifest.scenarios | Where-Object { $_.id -eq $Target }

# If not matched, try to match by file path
if ($selectedScenario -eq $null) {
    $normalizedTarget = $Target.Replace("\", "/")
    $selectedScenario = $manifest.scenarios | Where-Object { $_.file -eq $normalizedTarget -or $_.file.EndsWith($normalizedTarget) }
}

if ($selectedScenario -eq $null) {
    Write-Host "ERROR: Could not resolve target '$Target' to a valid scenario." -ForegroundColor Red
    Write-Host "Available Scenario IDs in manifest:" -ForegroundColor Yellow
    foreach ($scen in $manifest.scenarios) {
        Write-Host "  - $($scen.id) ($($scen.file))" -ForegroundColor Gray
    }
    exit 1
}

$scenId = $selectedScenario.id
$scenFile = $selectedScenario.file
$scenRelFile = "AGS/" + $scenFile

# 0. Clean up existing terminal instances before run
Kill-Terminal

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "AGS Single Scenario Tester (run_single_scenario.ps1)" -ForegroundColor Cyan
Write-Host "Target: $scenId ($scenFile)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 2. Sync TSDL scripts to Sandbox
Write-Host "Syncing TSDL scripts to Sandbox..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$CommonPath\Core" -Force | Out-Null
New-Item -ItemType Directory -Path "$CommonPath\Trade" -Force | Out-Null
New-Item -ItemType Directory -Path "$CommonPath\Resilience" -Force | Out-Null

Copy-Item -Path "$WorkspaceScripts\Core\*.tsd" -Destination "$CommonPath\Core\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$WorkspaceScripts\Trade\*.tsd" -Destination "$CommonPath\Trade\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$WorkspaceScripts\Resilience\*.tsd" -Destination "$CommonPath\Resilience\" -Force -ErrorAction SilentlyContinue
Write-Host "TSDL script sync complete." -ForegroundColor Green

# 3. Prepare Database
$dbDir = Split-Path -Path $CommonPath
$TemplateDb = Join-Path -Path $dbDir -ChildPath "ats.db"
$TargetDb = Join-Path -Path $dbDir -ChildPath "AGS.db"
if (Test-Path -Path $TemplateDb) {
    Copy-Item -Path $TemplateDb -Destination $TargetDb -Force
    Write-Host "Database AGS.db prepared from template." -ForegroundColor Green
} else {
    Write-Host "WARNING: Template database ats.db NOT found." -ForegroundColor Yellow
}

# 4. Setup target file and run
$targetFilePath = "$CommonPath\scenario_target.txt"
$resultFilePath = "$CommonPath\scenario_result.txt"

if (Test-Path -Path $targetFilePath) { Remove-Item -Path $targetFilePath -Force }
Clear-ResultFile -path $resultFilePath

# Write target file for the runner
$scenRelFile | Out-File -FilePath $targetFilePath -Encoding ascii -NoNewline

Write-Host "Launching terminal with runner_startup.ini..." -ForegroundColor Gray
$process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:d:\Projects\AGS\runner_startup.ini" -PassThru -NoNewWindow
if ($process -ne $null) {
    Write-Host "Terminal process started successfully. PID: $($process.Id)" -ForegroundColor Gray
} else {
    Write-Host "ERROR: Start-Process returned null for scenario!" -ForegroundColor Red
    exit 1
}

# Wait for completion (Up to 40 seconds)
$maxWait = 40
$waited = 0
while (!(Test-Path -Path $resultFilePath) -and ($waited -lt $maxWait)) {
    Start-Sleep -Seconds 1
    $waited++
}

# Force kill terminal
Kill-Terminal

# Read results
$scenResult = [PSCustomObject]@{
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

Write-Host "==================================================" -ForegroundColor Cyan
if ($scenResult.status -eq "PASSED") {
    Write-Host "RESULT: PASSED (ticks: $($scenResult.ticks), passed: $($scenResult.passed))" -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: FAILED (failed: $($scenResult.failed), details: $($scenResult.details))" -ForegroundColor Red
    exit 1
}
