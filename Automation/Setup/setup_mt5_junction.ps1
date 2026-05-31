# setup_mt5_junction.ps1
# Usage: powershell -ExecutionPolicy Bypass -File ./setup_mt5_junction.ps1

$SourcePath = "D:\Projects\AGS"
$TargetPath = "C:\Users\hsnote\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05\MQL5\Experts\AGS"

Write-Host "=================================================="
Write-Host "AGS MT5 Experts Junction Setup"
Write-Host "=================================================="

# 1. Check if source exists
if (!(Test-Path -Path $SourcePath)) {
    Write-Host "ERROR: Source project path not found: $SourcePath" -ForegroundColor Red
    exit 1
}

# 2. Remove existing link/directory if exists
if (Test-Path -Path $TargetPath) {
    Write-Host "Removing existing target: $TargetPath" -ForegroundColor Yellow
    # Handle junction removal carefully
    if ((Get-Item $TargetPath).Attributes -match "ReparsePoint") {
        # It's a junction/link
        Remove-Item -Path $TargetPath -Force
    } else {
        # It's a real directory (backup safety or just delete)
        Write-Host "Target is a real directory. Deleting recursively..." -ForegroundColor Gray
        Remove-Item -Path $TargetPath -Recurse -Force
    }
}

# 3. Create Junction
Write-Host "Creating Junction: $SourcePath -> $TargetPath" -ForegroundColor Cyan
try {
    New-Item -ItemType Junction -Path $TargetPath -Target $SourcePath -ErrorAction Stop | Out-Null
    Write-Host "SUCCESS: Junction established." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create junction. Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "=================================================="
