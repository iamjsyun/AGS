param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Load", "Unload")]
    [string]$Action,
    
    [string]$EaPath,
    [int]$ChartId = 0,
    [string]$CmdFile = "C:\Users\hijsyun\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DB\ea_command.txt"
)

# Ensure directory exists
$dir = Split-Path $CmdFile
if (!(Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

if ($Action -eq "Load") {
    $cmd = "LOAD|$EaPath|$ChartId"
} else {
    $cmd = "UNLOAD|$ChartId"
}

# Write command file
$cmd | Out-File -FilePath $CmdFile -Encoding ascii
Write-Host "[INFO] Command '$cmd' written to $CmdFile"
