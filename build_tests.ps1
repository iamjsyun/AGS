# build_tests.ps1
$compilerPath = "C:\Program Files\XM Global MT5\MetaEditor64.exe"
if (!(Test-Path -Path $compilerPath)) {
    $compilerPath = "D:\Program Files\XM Global MT5\MetaEditor64.exe"
}

$logDir = Join-Path -Path $PSScriptRoot -ChildPath "_log"
if (!(Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

function Build-File([string]$file, [string]$logName) {
    $projectPath = Join-Path -Path $PSScriptRoot -ChildPath $file
    $logFile = Join-Path -Path $logDir -ChildPath $logName
    if (Test-Path -Path $logFile) { Remove-Item -Path $logFile }
    
    Write-Host "Building $file..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $compilerPath -ArgumentList "/compile:$projectPath", "/log:$logFile" -Wait -NoNewWindow -PassThru
    
    if (Test-Path -Path $logFile) {
        $logContent = [System.IO.File]::ReadAllText($logFile, [System.Text.Encoding]::Unicode)
        if ($logContent -match 'Result:\s+0\s+errors') {
            Write-Host "$file compiled successfully." -ForegroundColor Green
            return $true
        } else {
            Write-Host "ERROR: $file compilation failed!" -ForegroundColor Red
            Write-Host $logContent -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "ERROR: No log generated for $file" -ForegroundColor Red
        return $false
    }
}

$ok1 = Build-File "MT5\_Test\AGSTestRunner.mq5" "build_testrunner.log"
$ok2 = Build-File "MT5\_Test\AGSScenarioRunner.mq5" "build_scenariorunner.log"

if ($ok1 -and $ok2) {
    exit 0
} else {
    exit 1
}
