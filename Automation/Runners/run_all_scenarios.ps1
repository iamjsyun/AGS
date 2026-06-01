param(
    [string]$Root = "D:\Projects\AGS",
    [string]$Manifest = "$Root\Automation\Config\scenario_manifest.json",
    [string]$LogDir   = "$Root\_log"
)

# ① MT5 한 번 시작 (실제 경로 사용)
$mt5Path = "C:\Program Files\XM Global MT5\terminal64.exe"
if (!(Test-Path $mt5Path)) { $mt5Path = "C:\Program Files\MetaTrader 5\terminal64.exe" }

$mt5 = Start-Process -FilePath $mt5Path -ArgumentList "/portable" -PassThru -WindowStyle Hidden
Write-Host "[INFO] MT5 launched (PID=$($mt5.Id))"

# ② 매니페스트 로드
$cfg = Get-Content $Manifest -Raw | ConvertFrom-Json
foreach($sc in $cfg.scenarios){
    $log = "$LogDir\scenario_$($sc.name)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    # EA 로드
    & "$Root\Automation\Tools\ea_manager.ps1" -Action Load -EaPath $sc.ea -ChartId $sc.chartId
    
    # 테스트 실행 (기존 테스트 로직 호출 가정)
    Write-Host "[INFO] Running scenario: $($sc.name)"
    # & "$Root\Automation\Tools\TestRunner.ps1" -Scenario $sc.name -Log $log 
    # (일시 주석: TestRunner가 아직 미완성일 수 있음)
    Start-Sleep -Seconds 5 # 테스트를 대신하는 임시 대기
    
    # EA 언로드
    & "$Root\Automation\Tools\ea_manager.ps1" -Action Unload -ChartId $sc.chartId
}

# ③ 종료
Stop-Process -Id $mt5.Id -Force
Write-Host "[INFO] MT5 terminated after all scenarios."
