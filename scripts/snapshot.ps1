# Snapshot — saves a named checkpoint of current work state
# Usage: .\snapshot.ps1 -Name "before-refactor"

param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Notes = ""
)

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MACHINE_NAME = $env:COMPUTERNAME
$TS = Get-Date -Format "yyyy-MM-dd-HHmmss"
$SNAP_DIR = "$BRAIN_DIR\snapshots"

if (-not (Test-Path $SNAP_DIR)) { New-Item -ItemType Directory $SNAP_DIR | Out-Null }

# Get current git state of the working directory
$gitStatus = & git status --short 2>&1 | Out-String
$gitLog = & git log --oneline -5 2>&1 | Out-String
$branch = & git branch --show-current 2>&1

$snap = @"
---
name: $Name
machine: $MACHINE_NAME
timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
branch: $branch
---

# Snapshot: $Name

## Notes
$Notes

## Git status
$gitStatus

## Recent commits
$gitLog

## Current handoff
$(if (Test-Path "$BRAIN_DIR\handoff\current.md") { Get-Content "$BRAIN_DIR\handoff\current.md" -Raw } else { "none" })
"@

$snapFile = "$SNAP_DIR\$TS-$Name.md"
$snap | Set-Content $snapFile -Encoding UTF8

Write-Host "✓ Snapshot saved: snapshots\$TS-$Name.md" -ForegroundColor Green

# Auto-sync
& powershell -NonInteractive -File "$BRAIN_DIR\sync.ps1" "snapshot: $Name" 2>&1 | Out-Null
Write-Host "✓ Synced to brain." -ForegroundColor Green
