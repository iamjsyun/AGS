$Root = "D:\Projects\AGS"
$manifestPath = "$Root\Automation\Config\scenario_manifest.json"
$cfg = Get-Content $manifestPath -Raw | ConvertFrom-Json

Write-Host "[INFO] Starting batch unit tests..." -ForegroundColor Cyan

foreach ($scenario in $cfg.scenarios) {
    Write-Host "[INFO] Running: $($scenario.id)" -ForegroundColor Green
    & "$Root\Automation\Tools\TestRunner.ps1" -ScenarioId $scenario.id -Root $Root
    Start-Sleep -Seconds 2
}

Write-Host "[INFO] Batch unit tests completed." -ForegroundColor Cyan
