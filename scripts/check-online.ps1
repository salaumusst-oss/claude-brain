# Returns whether the OTHER machine is online (heartbeat < 2 min old)
param([string]$BrainDir = "C:\Users\musst\claude-brain")

$MY_MACHINE = $env:COMPUTERNAME

# Pull latest heartbeats
& git -C $BrainDir pull 2>&1 | Out-Null

$beats = Get-ChildItem "$BrainDir\heartbeat" -Filter "*.json" -ErrorAction SilentlyContinue |
         Where-Object { $_.BaseName -ne $MY_MACHINE }

if (-not $beats) {
    Write-Output "offline"
    exit 0
}

$now = [int][double]::Parse((Get-Date -UFormat %s))
$THRESHOLD = 120  # 2 minutes

foreach ($beat in $beats) {
    try {
        $data = Get-Content $beat.FullName | ConvertFrom-Json
        $age = $now - $data.epoch
        if ($age -lt $THRESHOLD) {
            Write-Output "online:$($data.machine)"
            exit 0
        }
    } catch {}
}

Write-Output "offline"
