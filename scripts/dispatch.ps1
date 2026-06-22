param(
    [Parameter(Mandatory)][string]$Task,
    [string]$ContextFiles = "",
    [string]$BrainDir = "C:\Users\musst\claude-brain",
    [switch]$ForceAlone,
    [switch]$ForceSplit
)

$MY_MACHINE = $env:COMPUTERNAME
$TS = Get-Date -Format "yyyyMMdd-HHmmss"

function Write-Status { param([string]$Msg, $Color="Cyan") Write-Host $Msg -ForegroundColor $Color }

# Check if other machine is online
$otherStatus = & powershell -NonInteractive -File "$BrainDir\scripts\check-online.ps1" -BrainDir $BrainDir
$otherOnline = $otherStatus -match "^online:"
$otherMachine = if ($otherOnline) { $otherStatus.Split(":")[1] } else { $null }

Write-Status "Task: $Task"
Write-Status "Other machine: $(if ($otherOnline) { "$otherMachine (ONLINE)" } else { "OFFLINE" })" $(if ($otherOnline) { "Green" } else { "Yellow" })

$splitMode = ($otherOnline -and -not $ForceAlone) -or $ForceSplit

if ($splitMode) {
    Write-Status "SPLIT MODE - dispatching half to $otherMachine" "Magenta"

    $remoteTaskFile = "$BrainDir\tasks\$TS-$otherMachine-pending.md"
    $ts_now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $remoteContent = "---`nid: $TS`nfrom: $MY_MACHINE`nto: $otherMachine`nmode: split-remote`nstatus: pending`ntask: $Task`ncontext_files: $ContextFiles`ncreated: $ts_now`n---`n`n# Remote Task`n`nYou are the REMOTE instance. LOCAL ($MY_MACHINE) is handling the other half.`n`n## Your job`n$Task`n`n## Split responsibility`nYou handle: research, planning, backend/data/API work`nLocal handles: implementation, UI, assembly`n`n## Context files`n$ContextFiles`n`n## Output`nWrite your complete findings after a line that says: ## RESULT"
    $remoteContent | Set-Content $remoteTaskFile -Encoding UTF8

    & git -C $BrainDir add -A 2>&1 | Out-Null
    & git -C $BrainDir commit -m "task dispatched $TS to $otherMachine" 2>&1 | Out-Null
    & git -C $BrainDir push origin main 2>&1 | Out-Null

    Write-Status "Remote task dispatched to $otherMachine. Task ID: $TS" "Yellow"

    $output = "SPLIT TASK - LOCAL INSTANCE`nOther machine ($otherMachine) is handling: research, planning, backend/data work.`nTask ID: $TS`n`nYOUR JOB: Handle implementation, UI, and final assembly.`nStart now. Do NOT wait for remote before starting.`nWhen done check for remote result at: $BrainDir\tasks\$TS-$otherMachine-done.md`n`nTHE TASK: $Task`nContext: $ContextFiles"
    Write-Output $output

} else {
    Write-Status "SOLO MODE - other machine offline, handling everything here" "Cyan"

    $soloFile = "$BrainDir\tasks\$TS-$MY_MACHINE-solo.md"
    $ts_now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $soloContent = "---`nid: $TS`nmachine: $MY_MACHINE`nmode: solo`nstatus: pending`ntask: $Task`ncontext_files: $ContextFiles`ncreated: $ts_now`n---`n`n# Solo Task (other machine offline)`n`n$Task`n`nContext: $ContextFiles"
    $soloContent | Set-Content $soloFile -Encoding UTF8

    & git -C $BrainDir add -A 2>&1 | Out-Null
    & git -C $BrainDir commit -m "task solo $TS" 2>&1 | Out-Null
    & git -C $BrainDir push origin main 2>&1 | Out-Null

    $output = "SOLO TASK - Task ID: $TS`n`nOther machine is offline. Handle everything here.`n`nTHE TASK: $Task`nContext: $ContextFiles"
    Write-Output $output
}
