# run_scenario_backtest.ps1
$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
if (!(Test-Path -Path $TerminalPath)) { $TerminalPath = "D:\Program Files\XM Global MT5\terminal64.exe" }
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"
$TerminalDataPath = "C:\Users\hsnote\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05"
$ConfigBackupPath = "D:\Projects\AGS\.tmp_scen_bt_backup"
$ManifestPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\..\Test\01_Scenarios\scenario_manifest.json"))

function Kill-Terminal {
    Get-Process -Name "terminal64" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

function Backup-Login {
    Write-Host "Backing up current terminal login info..." -ForegroundColor Gray
    if (Test-Path "$TerminalDataPath\config") {
        if (Test-Path $ConfigBackupPath) { Remove-Item $ConfigBackupPath -Recurse -Force }
        Copy-Item -Path "$TerminalDataPath\config" -Destination $ConfigBackupPath -Recurse -Force
        Write-Host "Backup complete." -ForegroundColor Green
    }
}

function Restore-Login {
    Write-Host "Restoring terminal login info..." -ForegroundColor Gray
    if (Test-Path $ConfigBackupPath) {
        Kill-Terminal
        Copy-Item -Path "$ConfigBackupPath\*" -Destination "$TerminalDataPath\config" -Recurse -Force
        Remove-Item $ConfigBackupPath -Recurse -Force
        Write-Host "Restore complete." -ForegroundColor Green
    }
}

Kill-Terminal
Backup-Login

if (!(Test-Path -Path $ManifestPath)) { Write-Host "ERROR: Manifest not found." -ForegroundColor Red; exit 1 }
$manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json

Write-Host "Launching Backtest Scenario Batch Execution..." -ForegroundColor Cyan
$iniPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\..\Test\02_Config\scenario_backtest.ini"))

foreach ($scen in $manifest.scenarios) {
    Write-Host "-> Running Scenario (BT): $($scen.id)" -ForegroundColor Cyan
    
    $targetFile = "$CommonPath\scenario_target.txt"
    $resultFile = "$CommonPath\scenario_result.txt"
    if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
    ("AGS/" + $scen.file) | Out-File -FilePath $targetFile -Encoding ascii -NoNewline
    
    $proc = Start-Process -FilePath $TerminalPath -ArgumentList "/config:$iniPath /login:315136196 /password:'xmDemo@2025' /server:'XMGlobal-MT5 7' /experts:on" -PassThru -NoNewWindow
    
    $maxWait = 60
    $waited = 0
    while (!(Test-Path $resultFile) -and ($waited -lt $maxWait)) { Start-Sleep -Seconds 1; $waited++ }
    
    Kill-Terminal
    
    if (Test-Path $resultFile) {
        Get-Content $resultFile | Write-Host -ForegroundColor Gray
    } else {
        Write-Host "  [FAIL] Timeout for scenario $($scen.id)" -ForegroundColor Red
    }
}

Restore-Login
Write-Host "Scenario Batch Execution Finished." -ForegroundColor Green
