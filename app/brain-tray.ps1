# Claude Brain — System Tray Background Agent
# Runs silently, shows notifications when other machine sends handoff/inbox

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MACHINE_NAME = $env:COMPUTERNAME

function Sync-Brain {
    $script = "$BRAIN_DIR\sync.ps1"
    if (Test-Path $script) {
        & powershell -NonInteractive -File $script "tray-sync" 2>&1 | Out-Null
    }
}

function Show-Notification {
    param([string]$Title, [string]$Message, [System.Windows.Forms.ToolTipIcon]$Icon = 'Info')
    $tray.ShowBalloonTip(4000, $Title, $Message, $Icon)
}

# Tray icon
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Text = "Claude Brain"
$tray.Visible = $true

# Use a built-in icon
$tray.Icon = [System.Drawing.SystemIcons]::Application

# Context menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miOpen = New-Object System.Windows.Forms.ToolStripMenuItem "Open Dashboard"
$miSync = New-Object System.Windows.Forms.ToolStripMenuItem "Sync Now"
$miStatus = New-Object System.Windows.Forms.ToolStripMenuItem "Status: checking..."
$miStatus.Enabled = $false
$miSep = New-Object System.Windows.Forms.ToolStripSeparator
$miExit = New-Object System.Windows.Forms.ToolStripMenuItem "Exit"

$menu.Items.AddRange(@($miOpen, $miSync, $miStatus, $miSep, $miExit))
$tray.ContextMenuStrip = $menu

$miOpen.Add_Click({
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$BRAIN_DIR\app\brain.ps1`"" -WindowStyle Hidden
})

$miSync.Add_Click({
    Sync-Brain
    Show-Notification "Claude Brain" "Synced at $(Get-Date -Format 'HH:mm:ss')"
})

$miExit.Add_Click({
    $tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

# Track state between checks
$script:lastHandoffTime = ""
$script:lastInboxCount = 0

# Check for changes every 30 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({
    Sync-Brain

    # Check handoff
    $hFile = "$BRAIN_DIR\handoff\current.md"
    if (Test-Path $hFile) {
        $h = Get-Content $hFile -Raw
        if ($h -match "timestamp: (.+)") {
            $ts = $matches[1].Trim()
            if ($ts -ne $script:lastHandoffTime) {
                $script:lastHandoffTime = $ts
                if ($h -match "from: (.+)") {
                    $from = $matches[1].Trim()
                    if ($from -ne $MACHINE_NAME) {
                        Show-Notification "Claude Brain — Handoff Received" "From $from at $ts" 'Info'
                    }
                }
            }
        }
    }

    # Check inbox
    $msgs = Get-ChildItem "$BRAIN_DIR\inbox" -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.md" }
    $count = if ($msgs) { $msgs.Count } else { 0 }
    if ($count -gt $script:lastInboxCount) {
        $new = $count - $script:lastInboxCount
        Show-Notification "Claude Brain — New Message" "$new new inbox message(s)" 'Info'
        $script:lastInboxCount = $count
    }

    # Update status menu item
    try {
        $status = & git -C $BRAIN_DIR status --porcelain 2>&1
        $miStatus.Text = if ($status) { "Status: Unsynced changes" } else { "Status: Up to date ✓" }
    } catch {
        $miStatus.Text = "Status: Unknown"
    }
})

$timer.Start()

# Double-click opens dashboard
$tray.Add_DoubleClick({
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$BRAIN_DIR\app\brain.ps1`"" -WindowStyle Hidden
})

Show-Notification "Claude Brain" "Running on $MACHINE_NAME. Double-click to open."

# Run message loop
$appCtx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appCtx)
