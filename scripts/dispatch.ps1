# Dispatch — the main entry point for collaboration
# Called by Claude when you give it a task
# Decides: split across both machines, or handle alone
#
# Usage: .\dispatch.ps1 -Task "build a login page" -ContextFiles "src/app.ts"

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

# ── Check if other machine is online ────────────────────────────────────────
$otherStatus = & powershell -NonInteractive -File "$BrainDir\scripts\check-online.ps1" -BrainDir $BrainDir
$otherOnline = $otherStatus -match "^online:"
$otherMachine = if ($otherOnline) { $otherStatus.Split(":")[1] } else { $null }

Write-Status "Task: $Task"
Write-Status "Other machine: $(if ($otherOnline) { "$otherMachine (ONLINE)" } else { "OFFLINE" })" $(if ($otherOnline) { "Green" } else { "Yellow" })

# ── Decide mode ─────────────────────────────────────────────────────────────
$splitMode = ($otherOnline -and -not $ForceAlone) -or $ForceSplit

if ($splitMode) {
    Write-Status "`nSPLIT MODE — dispatching half to $otherMachine" "Magenta"

    # Write the remote task (for the other machine's watcher)
    $remoteTaskFile = "$BrainDir\tasks\$TS-$otherMachine-pending.md"
    @"
---
id: $TS
from: $MY_MACHINE
to: $otherMachine
mode: split-remote
status: pending
task: $Task
context_files: $ContextFiles
created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
---

# Remote Task

You are the REMOTE instance in a split task. The LOCAL instance ($MY_MACHINE) is handling the other half.

## Your job
$Task

### Split responsibility
- You handle: **research, planning, and any data/API/backend work**
- Local handles: **implementation, UI, and assembly**

When you finish, write your results clearly so the local instance can use them.

## Context files
$ContextFiles

## Output
Write your complete findings/output below the --- line and save this file as done.
"@ | Set-Content $remoteTaskFile -Encoding UTF8

    # Sync so the other machine picks it up
    & git -C $BrainDir add -A 2>&1 | Out-Null
    & git -C $BrainDir commit -m "task: dispatched $TS to $otherMachine" 2>&1 | Out-Null
    & git -C $BrainDir push origin main 2>&1 | Out-Null

    Write-Status "Remote task dispatched. Waiting for $otherMachine to pick it up..." "Yellow"

    # Write the local task prompt (returned for Claude to use)
    $localPrompt = @"
SPLIT TASK — You are the LOCAL instance.
The REMOTE instance ($otherMachine) has been dispatched and is handling: research, planning, and backend/data work.
Task ID: $TS

YOUR JOB (local): Handle implementation, UI, and final assembly.

IMPORTANT:
- Work on your part now. Do NOT wait for the remote instance before starting.
- When you finish your part, check if the remote result is ready by reading: $BrainDir\tasks\$TS-$otherMachine-done.md
- If the remote result is there, merge both outputs into the final answer.
- If not ready yet, save your progress and the merge will happen when remote finishes.

THE TASK: $Task

Context files: $ContextFiles
"@
    Write-Output $localPrompt

} else {
    Write-Status "`nSOLO MODE — handling everything on $MY_MACHINE" "Cyan"

    $soloPrompt = @"
SOLO TASK — The other machine is offline. You are handling everything.
Task ID: $TS

THE TASK: $Task

Context files: $ContextFiles

Handle this completely. When done, write a summary to: $BrainDir\inbox\$TS-$MY_MACHINE-result.md
"@
    Write-Output $soloPrompt
}
