# Heartbeat — runs in background, pulses every 60s so other machine knows this one is online
param([string]$BrainDir = "C:\Users\musst\claude-brain")

$MACHINE = $env:COMPUTERNAME
$FILE = "$BrainDir\heartbeat\$MACHINE.json"

while ($true) {
    $beat = @{
        machine   = $MACHINE
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        epoch     = [int][double]::Parse((Get-Date -UFormat %s))
        platform  = "windows"
    } | ConvertTo-Json

    $beat | Set-Content $FILE -Encoding UTF8

    # Sync quietly
    try {
        & git -C $BrainDir add "heartbeat/$MACHINE.json" 2>&1 | Out-Null
        & git -C $BrainDir commit -m "heartbeat: $MACHINE" --allow-empty 2>&1 | Out-Null
        & git -C $BrainDir push origin main 2>&1 | Out-Null
    } catch {}

    Start-Sleep -Seconds 60
}
