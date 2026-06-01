# validate_manifest.ps1
param(
    [string]$Manifest = "${PSScriptRoot}\..\Config\scenario_manifest.json",
    [string]$Report   = "${PSScriptRoot}\..\..\_log\validation_report.txt"
)

$errors = @()
if (!(Test-Path $Manifest)) {
    Write-Error "Manifest file not found at $Manifest"
    exit 1
}

try {
    $json = Get-Content $Manifest -Raw | ConvertFrom-Json
} catch {
    $errors += "[ERROR] Failed to parse JSON manifest: $($_.Exception.Message)"
}

if ($json) {
    if (!$json.scenarios) {
        $errors += "[ERROR] Manifest missing 'scenarios' array"
    } else {
        foreach($sc in $json.scenarios) {
            if (!$sc.id) { $errors += "[ERROR] Scenario missing 'id'" }
            if (!$sc.name) { $errors += "[ERROR] Scenario ($($sc.id)) missing 'name'" }
            if (!$sc.ea) { $errors += "[ERROR] Scenario ($($sc.id)) missing 'ea'" }
            if ($null -eq $sc.chartId) { $errors += "[ERROR] Scenario ($($sc.id)) missing 'chartId'" }
            if (!$sc.scope) { 
                $errors += "[ERROR] Scenario ($($sc.id)) missing 'scope'" 
            } else {
                if (!$sc.scope.stage) { $errors += "[ERROR] Scenario ($($sc.id)) scope missing 'stage'" }
                if (!$sc.scope.seq) { $errors += "[ERROR] Scenario ($($sc.id)) scope missing 'seq'" }
                if (!$sc.scope.task) { $errors += "[ERROR] Scenario ($($sc.id)) scope missing 'task'" }
                if (!$sc.scope.fn) { $errors += "[ERROR] Scenario ($($sc.id)) scope missing 'fn'" }
            }
        }
        
        # Check duplicate chartId
        $dupCharts = $json.scenarios | Group-Object -Property chartId | Where-Object { $_.Count -gt 1 -and $_.Name -ne "0" }
        if ($dupCharts) {
            foreach ($g in $dupCharts) {
                $errors += "[ERROR] Duplicate non-zero chartId $($g.Name) in scenarios: $(($g.Group.id) -join ', ')"
            }
        }
    }
}

# Create log directory if not exists
$reportDir = Split-Path $Report
if (!(Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

if ($errors.Count -eq 0) {
    $summary = "[PASS] Manifest validation succeeded at $(Get-Date)"
    $summary | Set-Content $Report
    Write-Host $summary -ForegroundColor Green
    exit 0
} else {
    $summary = "[FAIL] Manifest validation failed at $(Get-Date)"
    Write-Host $summary -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    
    # Save errors to report file
    $reportContent = @($summary) + $errors
    $reportContent | Set-Content $Report
    exit 1
}
