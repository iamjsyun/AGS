# Manual Monitor Script
$TargetFile = "C:\Users\hsnote\AppData\Roaming\MetaQuotes\Terminal\Common\Files\AGS\scenario_result.txt"
$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
$ConfigPath = "D:\Projects\AGS\Test\02_Config\unit_startup.ini"

Write-Host "Cleaning old result if exists..."
if (Test-Path $TargetFile) { Remove-Item $TargetFile }

Write-Host "Launching Terminal..."
$proc = Start-Process -FilePath $TerminalPath -ArgumentList "/config:$ConfigPath /login:315136196 /password:'xmDemo@2025' /server:'XMGlobal-MT5 7'" -PassThru

Write-Host "Monitoring for $TargetFile (max 2 minutes)..."
$timeout = 120
$elapsed = 0
while ($elapsed -lt $timeout) {
    if (Test-Path $TargetFile) {
        Write-Host "SUCCESS: Result file found!" -ForegroundColor Green
        Get-Content $TargetFile
        break
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "Waiting... ($elapsed/$timeout)"
}

if (!(Test-Path $TargetFile)) {
    Write-Host "FAILURE: Timeout waiting for result file." -ForegroundColor Red
}

Write-Host "Closing terminal..."
$proc | Stop-Process -Force
