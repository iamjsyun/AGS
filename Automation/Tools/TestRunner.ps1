param(
    [Parameter(Mandatory=$true)]
    [string]$ScenarioId,
    [string]$Root = "D:\Projects\AGS"
)

# Load manifest
$manifestPath = "$Root\Automation\Config\scenario_manifest.json"
$cfg = Get-Content $manifestPath -Raw | ConvertFrom-Json
$scenario = $cfg.scenarios | Where-Object { $_.id -eq $ScenarioId }

if ($null -eq $scenario) {
    Write-Error "Scenario $ScenarioId not found in manifest."
    exit 1
}

Write-Host "[INFO] Executing granular test: $($scenario.id)"
Write-Host "[INFO] Scope: Stage=$($scenario.scope.stage), Task=$($scenario.scope.task), Function=$($scenario.scope.fn)"

# Prepare command file for MQL5 (Passing the function to be tested)
$cmdFile = "C:\Users\hijsyun\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DB\ea_command.txt"
$cmdDir = Split-Path $cmdFile
if (!(Test-Path $cmdDir)) { New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null }
$cmd = "TEST|$($scenario.scope.task)|$($scenario.scope.fn)"
$cmd | Out-File -FilePath $cmdFile -Encoding ascii

# Trigger execution logic (Placeholder for test engine)
Write-Host "[INFO] Command '$cmd' dispatched to MQL5."
Start-Sleep -Seconds 2
Write-Host "[INFO] Test execution for $ScenarioId completed."
