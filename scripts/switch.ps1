# Quick machine switch — writes handoff and syncs
# Usage: .\switch.ps1 -Task "what you were doing" -Next "what to do next"

param(
    [string]$Task = "",
    [string]$Context = "",
    [string]$Next = "",
    [string]$To = "other"
)

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MACHINE_NAME = $env:COMPUTERNAME

# Interactive if no args
if (-not $Task) {
    Write-Host "`n🧠 Claude Brain — Quick Switch" -ForegroundColor Cyan
    Write-Host "══════════════════════════════" -ForegroundColor DarkGray
    $Task = Read-Host "What were you working on?"
    $Context = Read-Host "Key context (press Enter to skip)"
    $Next = Read-Host "Next steps for the other machine"
    $To = Read-Host "Switching to which machine? (press Enter for 'other')"
    if (-not $To) { $To = "other" }
}

$ts = Get-Date -Format "yyyy-MM-dd HH:mm"
$content = @"
---
from: $MACHINE_NAME
to: $To
timestamp: $ts
status: active
---

# Current Handoff

## Task
$Task

## Context
$Context

## Files touched
$(& git -C $BRAIN_DIR diff --name-only HEAD 2>&1 | Out-String)

## Next steps
$Next
"@

$content | Set-Content "$BRAIN_DIR\handoff\current.md" -Encoding UTF8

Write-Host "`nSyncing…" -ForegroundColor Yellow
& powershell -NonInteractive -File "$BRAIN_DIR\sync.ps1" "switch: $MACHINE_NAME → $To" 2>&1 | Out-Null

Write-Host "`n✓ Handoff written and synced!" -ForegroundColor Green
Write-Host "  From    : $MACHINE_NAME" -ForegroundColor DarkGray
Write-Host "  To      : $To" -ForegroundColor DarkGray
Write-Host "  Task    : $Task" -ForegroundColor DarkGray
Write-Host "`nOn the other machine, run:" -ForegroundColor Cyan
Write-Host "  git -C ~/claude-brain pull" -ForegroundColor White
Write-Host "  cat ~/claude-brain/handoff/current.md" -ForegroundColor White
