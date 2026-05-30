# AGS Build Script (v1.0)
# Purpose: Compiles AGS.mq5 project using MetaEditor64
# Requirements: Adheres to UTF-16 log encoding and structural standards defined in GEMINI.md

$MetaEditorPath = "D:\Program Files\XM Global MT5\MetaEditor64.exe"
$ProjectPath = "D:\Projects\AGS\MT5\04_AppBootstrap\AGS.mq5"
$LogDir = "D:\Projects\AGS\_log"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "build_$Timestamp.log"

if (-not (Test-Path $MetaEditorPath)) {
    Write-Error "MetaEditor64 not found at $MetaEditorPath"
    exit 1
}

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

Write-Host "Starting build: $ProjectPath"

# Compile command
$process = Start-Process -FilePath $MetaEditorPath -ArgumentList "/compile:`"$ProjectPath`" /log:`"$LogFile`"" -Wait -PassThru

# Convert log to UTF-16 as per standard
if (Test-Path $LogFile) {
    $content = Get-Content $LogFile
    $content | Out-File -FilePath $LogFile -Encoding Unicode
    Write-Host "Build finished. Log: $LogFile"
} else {
    Write-Host "Build finished, but no log file generated."
}

exit $process.ExitCode
