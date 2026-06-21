# Watcher — runs 24/7 on this machine, picks up tasks dispatched from the other machine
# Start it with: powershell -ExecutionPolicy Bypass -File watcher.ps1

param([string]$BrainDir = "C:\Users\musst\claude-brain")

$MY_MACHINE = $env:COMPUTERNAME
$TASKS_DIR = "$BrainDir\tasks"
$POLL_INTERVAL = 15  # seconds between GitHub pulls

Add-Type -AssemblyName System.Windows.Forms

function Log { param([string]$Msg) Write-Host "[$( Get-Date -Format 'HH:mm:ss')] $Msg" }
function Notify { param([string]$Title, [string]$Msg)
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = [System.Drawing.SystemIcons]::Application
    $n.Visible = $true
    $n.ShowBalloonTip(4000, $Title, $Msg, 'Info')
    Start-Sleep -Milliseconds 4500
    $n.Dispose()
}

function Process-Task {
    param([string]$TaskFile)

    $content = Get-Content $TaskFile -Raw
    $taskName = Split-Path $TaskFile -Leaf

    # Parse fields
    $task = if ($content -match "task: (.+)") { $matches[1].Trim() } else { "unknown task" }
    $fromMachine = if ($content -match "from: (.+)") { $matches[1].Trim() } else { "unknown" }
    $id = if ($content -match "id: (.+)") { $matches[1].Trim() } else { "unknown" }

    Log "Picking up task from $fromMachine: $task"
    Notify "Claude Brain — Task Received" "From $fromMachine: $task"

    # Mark as active
    $activeFile = $TaskFile -replace "-pending\.md$", "-active.md"
    Move-Item $TaskFile $activeFile -Force
    & git -C $BrainDir add -A 2>&1 | Out-Null
    & git -C $BrainDir commit -m "task: $MY_MACHINE picked up $id" 2>&1 | Out-Null
    & git -C $BrainDir push origin main 2>&1 | Out-Null

    # Run Claude on the task
    Log "Running Claude on task $id..."
    $claudePrompt = @"
You are the REMOTE Claude instance in a two-machine collaboration.
The LOCAL instance on $fromMachine dispatched this task to you.

$content

Complete your assigned work thoroughly. When done, write your FULL results/output at the end of this file after a line that says "## RESULT".
Save the file when complete. The local instance is waiting for your output.
"@

    # Write prompt to temp file for claude to read
    $promptFile = "$BrainDir\tasks\$id-prompt.md"
    $claudePrompt | Set-Content $promptFile -Encoding UTF8

    # Try to find claude executable
    $claudeExe = Get-Command "claude" -ErrorAction SilentlyContinue
    if (-not $claudeExe) {
        $claudeExe = Get-Command "$env:APPDATA\npm\claude.cmd" -ErrorAction SilentlyContinue
    }

    if ($claudeExe) {
        # Run claude non-interactively with the task
        $result = & claude --print $claudePrompt 2>&1 | Out-String
    } else {
        # Claude not in PATH — write task to a visible window for manual pickup
        $result = "WAITING_FOR_MANUAL: Claude CLI not found in PATH. Open the task file and run Claude manually."
        Log "WARNING: claude CLI not found. Task written to active file for manual pickup."
        Notify "Claude Brain — Manual Action Needed" "Claude CLI not found. Open task $id manually."
    }

    # Write result to done file
    $doneFile = $activeFile -replace "-active\.md$", "-done.md"
    $finalContent = $content + "`n`n## RESULT`n`n" + $result
    $finalContent | Set-Content $doneFile -Encoding UTF8
    Remove-Item $activeFile -Force -ErrorAction SilentlyContinue
    Remove-Item $promptFile -Force -ErrorAction SilentlyContinue

    # Sync result back
    & git -C $BrainDir add -A 2>&1 | Out-Null
    & git -C $BrainDir commit -m "task: $MY_MACHINE completed $id" 2>&1 | Out-Null
    & git -C $BrainDir push origin main 2>&1 | Out-Null

    Log "Task $id complete. Result synced back to $fromMachine."
    Notify "Claude Brain — Task Done" "Completed: $task"
}

Log "Watcher started on $MY_MACHINE. Polling every ${POLL_INTERVAL}s..."
Log "Watching: $TASKS_DIR"

while ($true) {
    try {
        # Pull latest
        & git -C $BrainDir pull 2>&1 | Out-Null

        # Look for tasks addressed to this machine
        $pending = Get-ChildItem $TASKS_DIR -Filter "*-$MY_MACHINE-pending.md" -ErrorAction SilentlyContinue

        foreach ($task in $pending) {
            Process-Task $task.FullName
        }

        # Write heartbeat
        $beat = @{
            machine   = $MY_MACHINE
            timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            epoch     = [int][double]::Parse((Get-Date -UFormat %s))
            platform  = "windows"
        } | ConvertTo-Json
        $beat | Set-Content "$BrainDir\heartbeat\$MY_MACHINE.json" -Encoding UTF8
        & git -C $BrainDir add "heartbeat/$MY_MACHINE.json" 2>&1 | Out-Null
        & git -C $BrainDir commit -m "heartbeat: $MY_MACHINE" 2>&1 | Out-Null
        & git -C $BrainDir push origin main 2>&1 | Out-Null

    } catch {
        Log "Error: $_"
    }

    Start-Sleep -Seconds $POLL_INTERVAL
}
