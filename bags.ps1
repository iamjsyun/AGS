# AGS Build Script (bags.ps1)
# Usage: ./bags.ps1

$compilerPath = "C:\Program Files\XM Global MT5\MetaEditor64.exe"
if (!(Test-Path -Path $compilerPath)) {
    $compilerPath = "D:\Program Files\XM Global MT5\MetaEditor64.exe"
}
$projectPath = Join-Path -Path $PSScriptRoot -ChildPath "MT5\AGS.mq5"
$logDir = Join-Path -Path $PSScriptRoot -ChildPath "_log"

# Create log directory if it doesn't exist
if (!(Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd"
$logFile = Join-Path -Path $logDir -ChildPath "build_$timestamp.log"

# Delete existing log file if it exists
if (Test-Path -Path $logFile) {
    Remove-Item -Path $logFile
}

Write-Host "Building project: $projectPath" -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Cyan

# Execute build synchronously and capture exit code (using correct MT5 parameter syntax)
$process = Start-Process -FilePath $compilerPath -ArgumentList "/compile:$projectPath", "/log:$logFile" -Wait -NoNewWindow -PassThru
$exitCode = $process.ExitCode

# Determine success based on the log file contents ("0 errors") and process exit code
$isSuccess = $false
if (Test-Path -Path $logFile) {
    $logContent = [System.IO.File]::ReadAllText($logFile, [System.Text.Encoding]::Unicode)
    if ($logContent -match 'Result:\s+0\s+errors') {
        $isSuccess = $true
    }
} else {
    if ($exitCode -eq 1) {
        $isSuccess = $true
    }
}

if ($isSuccess) {
    Write-Host "Build successful." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Build failed with exit code: $exitCode" -ForegroundColor Red
    if (Test-Path -Path $logFile) {
        Write-Host "--- Build Log ---" -ForegroundColor Yellow
        Write-Host $logContent
    }
    exit 1
}
