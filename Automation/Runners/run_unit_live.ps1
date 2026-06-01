# run_unit_live.ps1
$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
if (!(Test-Path -Path $TerminalPath)) { $TerminalPath = "D:\Program Files\XM Global MT5\terminal64.exe" }
$CommonPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\AGS"
$TerminalDataPath = "C:\Users\hijsyun\AppData\Roaming\MetaQuotes\Terminal\540829AD6BE27960E4557E2CFD5C69E0"
$ConfigBackupPath = "D:\Projects\AGS\.tmp_unit_live_backup"

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

if (!(Test-Path -Path $CommonPath)) { New-Item -ItemType Directory -Path $CommonPath -Force | Out-Null }
$resultPath = "$CommonPath\scenario_result.txt"
if (Test-Path -Path $resultPath) { Remove-Item -Path $resultPath -Force }

# Signal the runner that it should run all unit tests
"UNIT_TEST" | Out-File -FilePath "$CommonPath\scenario_target.txt" -Encoding ascii -NoNewline

Write-Host "Launching Live Unit Tests..." -ForegroundColor Cyan
$iniPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\..\Test\02_Config\unit_live.ini"))

$proc = Start-Process -FilePath $TerminalPath -ArgumentList "/config:$iniPath /experts:on" -PassThru -NoNewWindow
Write-Host "Terminal started (PID: $($proc.Id)). Waiting for results..."

$maxWait = 120
$waited = 0
while (!(Test-Path -Path $resultPath) -and ($waited -lt $maxWait)) {
    Start-Sleep -Seconds 1
    $waited++
}

Kill-Terminal
Restore-Login

if (Test-Path -Path $resultPath) {
    Write-Host "--- Unit Test Results ---" -ForegroundColor Yellow
    Get-Content $resultPath | Write-Host -ForegroundColor Gray
    Write-Host "Live Unit Test Execution Finished." -ForegroundColor Green
} else {
    Write-Host "ERROR: Live unit test timed out!" -ForegroundColor Red
}
