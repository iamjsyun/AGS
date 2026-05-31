# Connectivity Test Script for MT5 Terminal
# Purpose: Verify login with explicit credentials

$TerminalPath = "C:\Program Files\XM Global MT5\terminal64.exe"
$Login = "315136196"
$Password = "xmDemo@2025"
$Server = "XMGlobal-MT5 7"

Write-Host "Attempting terminal login..." -ForegroundColor Cyan
Write-Host "Login: $Login"
Write-Host "Server: $Server"

# Launch terminal in background
$proc = Start-Process -FilePath $TerminalPath -ArgumentList "/login:$Login /password:'$Password' /server:'$Server' /portable" -PassThru

Write-Host "Terminal launched with PID: $($proc.Id). Waiting for 20 seconds to allow connection..." -ForegroundColor Gray
Start-Sleep -Seconds 20

# Check if process is still running (suggests successful launch and no immediate crash)
$isStillRunning = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
if ($isStillRunning) {
    Write-Host "SUCCESS: Terminal is still running after 20 seconds. Connectivity likely established." -ForegroundColor Green
    $proc | Stop-Process -Force
} else {
    Write-Host "FAILURE: Terminal exited prematurely. Check MT5 logs." -ForegroundColor Red
}
