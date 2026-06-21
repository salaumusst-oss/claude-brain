# Daily Digest — summarizes recent brain activity
# Schedule with Task Scheduler to run each morning

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MACHINE_NAME = $env:COMPUTERNAME

# Pull latest
& git -C $BRAIN_DIR pull 2>&1 | Out-Null

# Git log last 24h
$since = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd HH:mm")
$commits = & git -C $BRAIN_DIR log --oneline --since="$since" 2>&1 | Out-String

# Inbox count
$msgs = Get-ChildItem "$BRAIN_DIR\inbox" -Filter "*.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "README.md" }

# Handoff status
$handoff = if (Test-Path "$BRAIN_DIR\handoff\current.md") {
    $h = Get-Content "$BRAIN_DIR\handoff\current.md" -Raw
    if ($h -match "status: (.+)") { $matches[1].Trim() } else { "unknown" }
} else { "none" }

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$digest = @"
---
from: digest-bot ($MACHINE_NAME)
type: daily-digest
timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
---

# Daily Brain Digest — $(Get-Date -Format 'dddd, MMMM dd')

## Activity (last 24h)
$commits

## Inbox
$($msgs.Count) message(s) waiting

## Handoff status
$handoff

## Memory files
$(( Get-ChildItem "$BRAIN_DIR\memory" -Filter "*.md" -ErrorAction SilentlyContinue ).Count) files in shared memory
"@

$digest | Set-Content "$BRAIN_DIR\inbox\$ts-digest.md" -Encoding UTF8
& git -C $BRAIN_DIR add -A
& git -C $BRAIN_DIR commit -m "digest: $(Get-Date -Format 'yyyy-MM-dd')"
& git -C $BRAIN_DIR push origin main 2>&1 | Out-Null

Write-Host "Digest posted." -ForegroundColor Green
