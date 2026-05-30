# build_tests.ps1
$compilerCandidates = @(
    "C:\Program Files\XM Global MT5\MetaEditor64.exe",
    "D:\Program Files\XM Global MT5\MetaEditor64.exe",
    "C:\Program Files\MetaTrader 5\metaeditor64.exe",
    "D:\Program Files\MetaTrader 5\metaeditor64.exe",
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
)
$compilerPath = $null
foreach ($path in $compilerCandidates) {
    if (Test-Path -Path $path) {
        $compilerPath = $path
        break
    }
}
if ($null -eq $compilerPath) {
    Write-Host "ERROR: MetaEditor64.exe not found in any candidate paths!" -ForegroundColor Red
    exit 1
}

$logDir = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\..\_log"))
if (!(Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

function Build-File([string]$file, [string]$logName) {
    $projectPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath $file))
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

$ok1 = Build-File "..\..\MT5\99_TestFramework\AGSTestRunner.mq5" "build_testrunner.log"
$ok2 = Build-File "..\..\MT5\99_TestFramework\AGSScenarioRunner.mq5" "build_scenariorunner.log"

if ($ok1 -and $ok2) {
    exit 0
} else {
    exit 1
}
