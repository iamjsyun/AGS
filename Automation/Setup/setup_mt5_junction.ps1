# setup_mt5_junction.ps1
# Usage: powershell -ExecutionPolicy Bypass -File ./setup_mt5_junction.ps1

$SourcePath = "D:\Projects\AGS"
$TargetPath = "C:\Users\hsnote\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05\MQL5\Experts\AGS"
$CommonTsdSource = "D:\Projects\AGS\Test\01_Scenarios"
$CommonTsdTarget = "C:\Users\hsnote\AppData\Roaming\MetaQuotes\Terminal\Common\Files\AGS"

Write-Host "=================================================="
Write-Host "AGS MT5 Junction Setup (Experts & TSDL)"
Write-Host "=================================================="

function Create-Junction($src, $tgt) {
    if (Test-Path -Path $tgt) {
        Write-Host "Removing existing target: $tgt" -ForegroundColor Yellow
        Remove-Item -Path $tgt -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Wait a moment for OS to release handles
    Start-Sleep -Milliseconds 500
    Write-Host "Creating Junction: $src -> $tgt" -ForegroundColor Cyan
    New-Item -ItemType Junction -Path $tgt -Target $src -ErrorAction Stop | Out-Null
}

try {
    Create-Junction $SourcePath $TargetPath
    Create-Junction $CommonTsdSource $CommonTsdTarget
    Write-Host "SUCCESS: All junctions established." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create junction. Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "=================================================="
