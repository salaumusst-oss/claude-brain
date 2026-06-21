Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MACHINE_NAME = $env:COMPUTERNAME
$CONFIG_FILE = "$BRAIN_DIR\app\config.json"

# Load or create config
if (Test-Path $CONFIG_FILE) {
    $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
} else {
    $config = [PSCustomObject]@{
        machineName = $MACHINE_NAME
        brainDir = $BRAIN_DIR
        autoSyncInterval = 60
    }
    $config | ConvertTo-Json | Set-Content $CONFIG_FILE
}

#region ── HELPERS ────────────────────────────────────────────────────────────

function Sync-Brain {
    param([string]$Message = "sync")
    $script = "$BRAIN_DIR\sync.ps1"
    if (Test-Path $script) {
        $result = & powershell -NonInteractive -File $script $Message 2>&1
        return $result -join "`n"
    }
    return "sync.ps1 not found"
}

function Get-HandoffContent {
    $f = "$BRAIN_DIR\handoff\current.md"
    if (Test-Path $f) { return Get-Content $f -Raw }
    return "No handoff file found."
}

function Set-HandoffContent {
    param([string]$Content)
    $f = "$BRAIN_DIR\handoff\current.md"
    $Content | Set-Content $f -Encoding UTF8
}

function Get-InboxMessages {
    $inbox = "$BRAIN_DIR\inbox"
    if (-not (Test-Path $inbox)) { return @() }
    return Get-ChildItem $inbox -Filter "*.md" | Where-Object { $_.Name -ne "README.md" } | Sort-Object LastWriteTime -Descending
}

function Get-MemoryFiles {
    $mem = "$BRAIN_DIR\memory"
    if (-not (Test-Path $mem)) { return @() }
    return Get-ChildItem $mem -Filter "*.md" | Sort-Object Name
}

function Get-LastSyncTime {
    try {
        $log = & git -C $BRAIN_DIR log -1 --format="%ci" 2>&1
        return $log
    } catch { return "unknown" }
}

function Get-BrainStatus {
    try {
        $status = & git -C $BRAIN_DIR status --porcelain 2>&1
        if ($status) { return "Unsynced changes" }
        return "Up to date"
    } catch { return "Git error" }
}

function Send-Inbox {
    param([string]$Message, [string]$To = "all")
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $file = "$BRAIN_DIR\inbox\$ts-$($config.machineName).md"
    $content = @"
---
from: $($config.machineName)
to: $To
timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
---

$Message
"@
    $content | Set-Content $file -Encoding UTF8
    Sync-Brain "inbox: message from $($config.machineName)" | Out-Null
}

function Write-Handoff {
    param([string]$Task, [string]$Context, [string]$Files, [string]$NextSteps, [string]$To)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    $content = @"
---
from: $($config.machineName)
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
$Files

## Next steps
$NextSteps
"@
    Set-HandoffContent $content
    Sync-Brain "handoff: from $($config.machineName) to $To" | Out-Null
}

#endregion

#region ── THEME ──────────────────────────────────────────────────────────────

$clrBg      = [System.Drawing.Color]::FromArgb(18, 18, 24)
$clrPanel   = [System.Drawing.Color]::FromArgb(28, 28, 38)
$clrCard    = [System.Drawing.Color]::FromArgb(38, 38, 52)
$clrAccent  = [System.Drawing.Color]::FromArgb(99, 102, 241)
$clrAccent2 = [System.Drawing.Color]::FromArgb(139, 92, 246)
$clrGreen   = [System.Drawing.Color]::FromArgb(52, 211, 153)
$clrYellow  = [System.Drawing.Color]::FromArgb(251, 191, 36)
$clrRed     = [System.Drawing.Color]::FromArgb(248, 113, 113)
$clrText    = [System.Drawing.Color]::FromArgb(229, 229, 229)
$clrMuted   = [System.Drawing.Color]::FromArgb(120, 120, 150)
$clrBorder  = [System.Drawing.Color]::FromArgb(55, 55, 75)

$fontMain   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontBold   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontTitle  = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$fontMono   = New-Object System.Drawing.Font("Cascadia Code", 9)
if (-not $fontMono) { $fontMono = New-Object System.Drawing.Font("Consolas", 9) }

function Style-Button {
    param($btn, [System.Drawing.Color]$bg = $clrAccent)
    $btn.BackColor = $bg
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.Font = $fontBold
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
}

function Style-TextBox {
    param($tb)
    $tb.BackColor = $clrCard
    $tb.ForeColor = $clrText
    $tb.BorderStyle = 'None'
    $tb.Font = $fontMono
}

function New-Label {
    param([string]$Text, [int]$X, [int]$Y, [int]$W=200, [int]$H=22, $Font=$fontMain, $Color=$clrText)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text; $lbl.Location = [System.Drawing.Point]::new($X,$Y)
    $lbl.Size = [System.Drawing.Size]::new($W,$H)
    $lbl.ForeColor = $Color; $lbl.Font = $Font; $lbl.BackColor = [System.Drawing.Color]::Transparent
    return $lbl
}

function New-Card {
    param([int]$X, [int]$Y, [int]$W, [int]$H)
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = [System.Drawing.Point]::new($X,$Y)
    $p.Size = [System.Drawing.Size]::new($W,$H)
    $p.BackColor = $clrCard
    return $p
}

#endregion

#region ── MAIN FORM ─────────────────────────────────────────────────────────

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Brain  —  $($config.machineName)"
$form.Size = [System.Drawing.Size]::new(1000, 680)
$form.MinimumSize = [System.Drawing.Size]::new(900, 600)
$form.BackColor = $clrBg
$form.ForeColor = $clrText
$form.Font = $fontMain
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'

# Header bar
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 56
$header.BackColor = $clrPanel
$form.Controls.Add($header)

$headerTitle = New-Label "🧠  Claude Brain" 16 14 300 30 $fontTitle $clrText
$header.Controls.Add($headerTitle)

$lblStatus = New-Label "● Checking..." 320 20 160 22 $fontMain $clrMuted
$header.Controls.Add($lblStatus)

$lblLastSync = New-Label "Last sync: —" 490 20 220 22 $fontMain $clrMuted
$header.Controls.Add($lblLastSync)

$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "⟳  Sync Now"
$btnSync.Size = [System.Drawing.Size]::new(110, 32)
$btnSync.Location = [System.Drawing.Point]::new(790, 12)
Style-Button $btnSync
$header.Controls.Add($btnSync)

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "⚙"
$btnSettings.Size = [System.Drawing.Size]::new(36, 32)
$btnSettings.Location = [System.Drawing.Point]::new(910, 12)
Style-Button $btnSettings $clrCard
$header.Controls.Add($btnSettings)

# Tab control
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.BackColor = $clrBg
$tabs.Font = $fontMain
$form.Controls.Add($tabs)

function New-Tab {
    param([string]$Title)
    $t = New-Object System.Windows.Forms.TabPage
    $t.Text = $Title
    $t.BackColor = $clrBg
    $t.Padding = [System.Windows.Forms.Padding]::new(0)
    $tabs.TabPages.Add($t)
    return $t
}

#endregion

#region ── TAB 1: DASHBOARD ──────────────────────────────────────────────────

$tabDash = New-Tab "  Dashboard  "

# Status cards row
$cardMe = New-Card 16 16 220 100
$tabDash.Controls.Add($cardMe)
$cardMe.Controls.Add((New-Label "THIS MACHINE" 12 10 196 16 $fontMain $clrMuted))
$lblMyName = New-Label $config.machineName 12 32 196 24 $fontBold $clrAccent
$cardMe.Controls.Add($lblMyName)
$lblMyStatus = New-Label "Status: checking…" 12 60 196 18 $fontMain $clrText
$cardMe.Controls.Add($lblMyStatus)

$cardOther = New-Card 252 16 220 100
$tabDash.Controls.Add($cardOther)
$cardOther.Controls.Add((New-Label "OTHER MACHINE" 12 10 196 16 $fontMain $clrMuted))
$lblOtherName = New-Label "Unknown" 12 32 196 24 $fontBold $clrAccent2
$cardOther.Controls.Add($lblOtherName)
$lblOtherStatus = New-Label "Last handoff: checking…" 12 60 196 18 $fontMain $clrText
$cardOther.Controls.Add($lblOtherStatus)

$cardSync = New-Card 488 16 220 100
$tabDash.Controls.Add($cardSync)
$cardSync.Controls.Add((New-Label "SYNC STATUS" 12 10 196 16 $fontMain $clrMuted))
$lblSyncStatus = New-Label "Checking…" 12 32 196 24 $fontBold $clrGreen
$cardSync.Controls.Add($lblSyncStatus)
$lblSyncTime = New-Label "—" 12 60 196 18 $fontMain $clrText
$cardSync.Controls.Add($lblSyncTime)

$cardInbox = New-Card 724 16 220 100
$tabDash.Controls.Add($cardInbox)
$cardInbox.Controls.Add((New-Label "INBOX" 12 10 196 16 $fontMain $clrMuted))
$lblInboxCount = New-Label "0 messages" 12 32 196 24 $fontBold $clrYellow
$cardInbox.Controls.Add($lblInboxCount)
$lblInboxLatest = New-Label "No messages" 12 60 196 18 $fontMain $clrText
$cardInbox.Controls.Add($lblInboxLatest)

# Current handoff preview
$tabDash.Controls.Add((New-Label "CURRENT HANDOFF" 16 132 200 18 $fontMain $clrMuted))
$txtHandoffPreview = New-Object System.Windows.Forms.RichTextBox
$txtHandoffPreview.Location = [System.Drawing.Point]::new(16, 154)
$txtHandoffPreview.Size = [System.Drawing.Size]::new(928, 200)
$txtHandoffPreview.ReadOnly = $true
Style-TextBox $txtHandoffPreview
$tabDash.Controls.Add($txtHandoffPreview)

# Activity log
$tabDash.Controls.Add((New-Label "ACTIVITY LOG" 16 370 200 18 $fontMain $clrMuted))
$lstActivity = New-Object System.Windows.Forms.ListBox
$lstActivity.Location = [System.Drawing.Point]::new(16, 392)
$lstActivity.Size = [System.Drawing.Size]::new(928, 200)
$lstActivity.BackColor = $clrCard
$lstActivity.ForeColor = $clrText
$lstActivity.Font = $fontMono
$lstActivity.BorderStyle = 'None'
$tabDash.Controls.Add($lstActivity)

function Add-Activity {
    param([string]$Msg)
    $ts = Get-Date -Format "HH:mm:ss"
    $lstActivity.Items.Insert(0, "[$ts]  $Msg")
    if ($lstActivity.Items.Count -gt 100) { $lstActivity.Items.RemoveAt(100) }
}

#endregion

#region ── TAB 2: HANDOFF ─────────────────────────────────────────────────────

$tabHandoff = New-Tab "  Handoff  "

$tabHandoff.Controls.Add((New-Label "Write a handoff for the other machine to pick up" 16 16 500 20 $fontMain $clrMuted))

$tabHandoff.Controls.Add((New-Label "To (machine name):" 16 44 160 20))
$txtTo = New-Object System.Windows.Forms.TextBox
$txtTo.Location = [System.Drawing.Point]::new(180, 42)
$txtTo.Size = [System.Drawing.Size]::new(200, 24)
Style-TextBox $txtTo
$txtTo.BorderStyle = 'FixedSingle'
$tabHandoff.Controls.Add($txtTo)

$tabHandoff.Controls.Add((New-Label "Task:" 16 78 160 20))
$txtHTask = New-Object System.Windows.Forms.TextBox
$txtHTask.Location = [System.Drawing.Point]::new(16, 98)
$txtHTask.Size = [System.Drawing.Size]::new(928, 24)
Style-TextBox $txtHTask; $txtHTask.BorderStyle = 'FixedSingle'
$tabHandoff.Controls.Add($txtHTask)

$tabHandoff.Controls.Add((New-Label "Context / what you did:" 16 132 300 20))
$txtHContext = New-Object System.Windows.Forms.RichTextBox
$txtHContext.Location = [System.Drawing.Point]::new(16, 152)
$txtHContext.Size = [System.Drawing.Size]::new(928, 100)
Style-TextBox $txtHContext
$tabHandoff.Controls.Add($txtHContext)

$tabHandoff.Controls.Add((New-Label "Files touched (one per line):" 16 264 300 20))
$txtHFiles = New-Object System.Windows.Forms.RichTextBox
$txtHFiles.Location = [System.Drawing.Point]::new(16, 284)
$txtHFiles.Size = [System.Drawing.Size]::new(928, 70)
Style-TextBox $txtHFiles
$tabHandoff.Controls.Add($txtHFiles)

$tabHandoff.Controls.Add((New-Label "Next steps (use checkboxes: - [ ] step):" 16 366 400 20))
$txtHNext = New-Object System.Windows.Forms.RichTextBox
$txtHNext.Location = [System.Drawing.Point]::new(16, 386)
$txtHNext.Size = [System.Drawing.Size]::new(928, 100)
Style-TextBox $txtHNext
$tabHandoff.Controls.Add($txtHNext)

$btnSendHandoff = New-Object System.Windows.Forms.Button
$btnSendHandoff.Text = "Send Handoff + Sync  →"
$btnSendHandoff.Size = [System.Drawing.Size]::new(200, 36)
$btnSendHandoff.Location = [System.Drawing.Point]::new(744, 500)
Style-Button $btnSendHandoff
$tabHandoff.Controls.Add($btnSendHandoff)

$btnClearHandoff = New-Object System.Windows.Forms.Button
$btnClearHandoff.Text = "Clear"
$btnClearHandoff.Size = [System.Drawing.Size]::new(80, 36)
$btnClearHandoff.Location = [System.Drawing.Point]::new(652, 500)
Style-Button $btnClearHandoff $clrCard
$tabHandoff.Controls.Add($btnClearHandoff)

$lblHandoffResult = New-Label "" 16 508 600 20 $fontMain $clrGreen
$tabHandoff.Controls.Add($lblHandoffResult)

$btnSendHandoff.Add_Click({
    $result = Write-Handoff -Task $txtHTask.Text -Context $txtHContext.Text -Files $txtHFiles.Text -NextSteps $txtHNext.Text -To $txtTo.Text
    $lblHandoffResult.Text = "✓ Handoff sent and synced at $(Get-Date -Format 'HH:mm:ss')"
    Add-Activity "Handoff sent to: $($txtTo.Text)"
    Update-Dashboard
})

$btnClearHandoff.Add_Click({
    $txtHTask.Text = ""; $txtHContext.Text = ""; $txtHFiles.Text = ""; $txtHNext.Text = ""; $txtTo.Text = ""
    $lblHandoffResult.Text = ""
})

#endregion

#region ── TAB 3: INBOX ───────────────────────────────────────────────────────

$tabInbox = New-Tab "  Inbox  "

# Left: message list
$tabInbox.Controls.Add((New-Label "MESSAGES" 16 16 200 18 $fontMain $clrMuted))
$lstInbox = New-Object System.Windows.Forms.ListBox
$lstInbox.Location = [System.Drawing.Point]::new(16, 38)
$lstInbox.Size = [System.Drawing.Size]::new(300, 460)
$lstInbox.BackColor = $clrCard
$lstInbox.ForeColor = $clrText
$lstInbox.Font = $fontMono
$lstInbox.BorderStyle = 'None'
$tabInbox.Controls.Add($lstInbox)

# Right: message content
$tabInbox.Controls.Add((New-Label "CONTENT" 332 16 200 18 $fontMain $clrMuted))
$txtInboxContent = New-Object System.Windows.Forms.RichTextBox
$txtInboxContent.Location = [System.Drawing.Point]::new(332, 38)
$txtInboxContent.Size = [System.Drawing.Size]::new(612, 320)
$txtInboxContent.ReadOnly = $true
Style-TextBox $txtInboxContent
$tabInbox.Controls.Add($txtInboxContent)

$btnDeleteMsg = New-Object System.Windows.Forms.Button
$btnDeleteMsg.Text = "Delete Message"
$btnDeleteMsg.Size = [System.Drawing.Size]::new(150, 32)
$btnDeleteMsg.Location = [System.Drawing.Point]::new(332, 368)
Style-Button $btnDeleteMsg $clrRed
$tabInbox.Controls.Add($btnDeleteMsg)

# Compose new message
$tabInbox.Controls.Add((New-Label "SEND MESSAGE" 332 416 200 18 $fontMain $clrMuted))
$txtNewMsg = New-Object System.Windows.Forms.RichTextBox
$txtNewMsg.Location = [System.Drawing.Point]::new(332, 438)
$txtNewMsg.Size = [System.Drawing.Size]::new(612, 60)
Style-TextBox $txtNewMsg
$txtNewMsg.BorderStyle = 'FixedSingle'
$tabInbox.Controls.Add($txtNewMsg)

$btnSendMsg = New-Object System.Windows.Forms.Button
$btnSendMsg.Text = "Send + Sync"
$btnSendMsg.Size = [System.Drawing.Size]::new(120, 32)
$btnSendMsg.Location = [System.Drawing.Point]::new(824, 510)
Style-Button $btnSendMsg
$tabInbox.Controls.Add($btnSendMsg)

$btnRefreshInbox = New-Object System.Windows.Forms.Button
$btnRefreshInbox.Text = "↻ Refresh"
$btnRefreshInbox.Size = [System.Drawing.Size]::new(100, 32)
$btnRefreshInbox.Location = [System.Drawing.Point]::new(16, 510)
Style-Button $btnRefreshInbox $clrCard
$tabInbox.Controls.Add($btnRefreshInbox)

$script:inboxFiles = @()

function Refresh-Inbox {
    $lstInbox.Items.Clear()
    $script:inboxFiles = Get-InboxMessages
    foreach ($f in $script:inboxFiles) {
        $lstInbox.Items.Add($f.Name)
    }
    $lblInboxCount.Text = "$($script:inboxFiles.Count) messages"
}

$lstInbox.Add_SelectedIndexChanged({
    $idx = $lstInbox.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:inboxFiles.Count) {
        $txtInboxContent.Text = Get-Content $script:inboxFiles[$idx].FullName -Raw
    }
})

$btnDeleteMsg.Add_Click({
    $idx = $lstInbox.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:inboxFiles.Count) {
        Remove-Item $script:inboxFiles[$idx].FullName -Force
        Add-Activity "Deleted inbox message: $($script:inboxFiles[$idx].Name)"
        Refresh-Inbox
        $txtInboxContent.Text = ""
        Sync-Brain "inbox: deleted message" | Out-Null
    }
})

$btnSendMsg.Add_Click({
    if ($txtNewMsg.Text.Trim()) {
        Send-Inbox -Message $txtNewMsg.Text.Trim()
        $txtNewMsg.Text = ""
        Refresh-Inbox
        Add-Activity "Message sent to inbox"
    }
})

$btnRefreshInbox.Add_Click({ Sync-Brain "pull" | Out-Null; Refresh-Inbox })

#endregion

#region ── TAB 4: MEMORY ──────────────────────────────────────────────────────

$tabMemory = New-Tab "  Memory  "

$tabMemory.Controls.Add((New-Label "SHARED MEMORY FILES" 16 16 300 18 $fontMain $clrMuted))

$lstMemory = New-Object System.Windows.Forms.ListBox
$lstMemory.Location = [System.Drawing.Point]::new(16, 38)
$lstMemory.Size = [System.Drawing.Size]::new(260, 500)
$lstMemory.BackColor = $clrCard
$lstMemory.ForeColor = $clrText
$lstMemory.Font = $fontMono
$lstMemory.BorderStyle = 'None'
$tabMemory.Controls.Add($lstMemory)

$txtMemContent = New-Object System.Windows.Forms.RichTextBox
$txtMemContent.Location = [System.Drawing.Point]::new(292, 38)
$txtMemContent.Size = [System.Drawing.Size]::new(652, 420)
Style-TextBox $txtMemContent
$tabMemory.Controls.Add($txtMemContent)

$btnSaveMemory = New-Object System.Windows.Forms.Button
$btnSaveMemory.Text = "Save + Sync"
$btnSaveMemory.Size = [System.Drawing.Size]::new(130, 32)
$btnSaveMemory.Location = [System.Drawing.Point]::new(814, 468)
Style-Button $btnSaveMemory
$tabMemory.Controls.Add($btnSaveMemory)

$btnNewMemory = New-Object System.Windows.Forms.Button
$btnNewMemory.Text = "+ New File"
$btnNewMemory.Size = [System.Drawing.Size]::new(120, 32)
$btnNewMemory.Location = [System.Drawing.Point]::new(16, 548)
Style-Button $btnNewMemory $clrAccent2
$tabMemory.Controls.Add($btnNewMemory)

$lblMemSaved = New-Label "" 292 472 500 20 $fontMain $clrGreen
$tabMemory.Controls.Add($lblMemSaved)

$script:memFiles = @()

function Refresh-Memory {
    $lstMemory.Items.Clear()
    $script:memFiles = Get-MemoryFiles
    foreach ($f in $script:memFiles) { $lstMemory.Items.Add($f.Name) }
}

$lstMemory.Add_SelectedIndexChanged({
    $idx = $lstMemory.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:memFiles.Count) {
        $txtMemContent.Text = Get-Content $script:memFiles[$idx].FullName -Raw
    }
})

$btnSaveMemory.Add_Click({
    $idx = $lstMemory.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:memFiles.Count) {
        $txtMemContent.Text | Set-Content $script:memFiles[$idx].FullName -Encoding UTF8
        Sync-Brain "memory: updated $($script:memFiles[$idx].Name)" | Out-Null
        $lblMemSaved.Text = "✓ Saved at $(Get-Date -Format 'HH:mm:ss')"
        Add-Activity "Memory saved: $($script:memFiles[$idx].Name)"
    }
})

$btnNewMemory.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("File name (without .md):", "New Memory File", "new-memory")
    if ($name) {
        $path = "$BRAIN_DIR\memory\$name.md"
        @"
---
name: $name
description:
metadata:
  type: user
---

"@ | Set-Content $path -Encoding UTF8
        Refresh-Memory
        Add-Activity "New memory file: $name.md"
    }
})

Add-Type -AssemblyName Microsoft.VisualBasic

#endregion

#region ── TAB 5: TERMINAL ────────────────────────────────────────────────────

$tabTerm = New-Tab "  Terminal  "
$tabTerm.Controls.Add((New-Label "Quick commands (output shown below)" 16 16 400 18 $fontMain $clrMuted))

$txtCmd = New-Object System.Windows.Forms.TextBox
$txtCmd.Location = [System.Drawing.Point]::new(16, 42)
$txtCmd.Size = [System.Drawing.Size]::new(780, 28)
Style-TextBox $txtCmd; $txtCmd.BorderStyle = 'FixedSingle'
$txtCmd.Font = $fontMono
$tabTerm.Controls.Add($txtCmd)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run"
$btnRun.Size = [System.Drawing.Size]::new(80, 28)
$btnRun.Location = [System.Drawing.Point]::new(804, 42)
Style-Button $btnRun
$tabTerm.Controls.Add($btnRun)

$txtOutput = New-Object System.Windows.Forms.RichTextBox
$txtOutput.Location = [System.Drawing.Point]::new(16, 80)
$txtOutput.Size = [System.Drawing.Size]::new(928, 460)
$txtOutput.ReadOnly = $true
Style-TextBox $txtOutput
$tabTerm.Controls.Add($txtOutput)

# Quick command buttons
$quickCmds = @(
    @{Label="git status"; Cmd="git -C `"$BRAIN_DIR`" status"},
    @{Label="git log"; Cmd="git -C `"$BRAIN_DIR`" log --oneline -10"},
    @{Label="git pull"; Cmd="git -C `"$BRAIN_DIR`" pull"},
    @{Label="list inbox"; Cmd="Get-ChildItem `"$BRAIN_DIR\inbox`""},
    @{Label="list memory"; Cmd="Get-ChildItem `"$BRAIN_DIR\memory`""}
)
$qx = 16
foreach ($q in $quickCmds) {
    $qb = New-Object System.Windows.Forms.Button
    $qb.Text = $q.Label; $qb.Size = [System.Drawing.Size]::new(100,24)
    $qb.Location = [System.Drawing.Point]::new($qx, 550)
    Style-Button $qb $clrCard
    $qCmd = $q.Cmd
    $qb.Add_Click({ $txtOutput.Text = (Invoke-Expression $qCmd 2>&1 | Out-String) })
    $tabTerm.Controls.Add($qb)
    $qx += 108
}

$runCmd = {
    $cmd = $txtCmd.Text.Trim()
    if ($cmd) {
        $txtOutput.Text = "$ $cmd`n`n"
        $out = Invoke-Expression $cmd 2>&1 | Out-String
        $txtOutput.Text += $out
        $txtCmd.Text = ""
        Add-Activity "Ran: $cmd"
    }
}
$btnRun.Add_Click($runCmd)
$txtCmd.Add_KeyDown({
    if ($_.KeyCode -eq 'Return') { & $runCmd }
})

#endregion

#region ── DASHBOARD UPDATE ───────────────────────────────────────────────────

function Update-Dashboard {
    # Brain status
    $gitStatus = Get-BrainStatus
    if ($gitStatus -eq "Up to date") {
        $lblSyncStatus.Text = "● Up to date"
        $lblSyncStatus.ForeColor = $clrGreen
    } else {
        $lblSyncStatus.Text = "● $gitStatus"
        $lblSyncStatus.ForeColor = $clrYellow
    }

    # Last sync
    $lastSync = Get-LastSyncTime
    $lblSyncTime.Text = $lastSync
    $lblLastSync.Text = "Last commit: $lastSync"

    # Handoff preview
    $h = Get-HandoffContent
    $txtHandoffPreview.Text = $h

    # Parse other machine from handoff
    if ($h -match "from: (.+)") { $lblOtherName.Text = $matches[1].Trim() }
    if ($h -match "timestamp: (.+)") { $lblOtherStatus.Text = "Last handoff: $($matches[1].Trim())" }

    # My status
    $lblMyStatus.Text = "Status: Active"
    $lblMyStatus.ForeColor = $clrGreen

    # Inbox
    Refresh-Inbox
    Refresh-Memory

    $lblStatus.Text = "● $gitStatus"
    $lblStatus.ForeColor = if ($gitStatus -eq "Up to date") { $clrGreen } else { $clrYellow }
}

#endregion

#region ── SYNC BUTTON & AUTO-SYNC ───────────────────────────────────────────

$btnSync.Add_Click({
    $btnSync.Text = "Syncing…"
    $btnSync.Enabled = $false
    $result = Sync-Brain "manual sync"
    $btnSync.Text = "⟳  Sync Now"
    $btnSync.Enabled = $true
    Add-Activity "Manual sync: $($result.Split("`n")[-1])"
    Update-Dashboard
})

# Auto-sync timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = ($config.autoSyncInterval * 1000)
$timer.Add_Tick({
    $result = Sync-Brain "auto-sync"
    Add-Activity "Auto-sync: $($result.Split("`n")[-1])"
    Update-Dashboard
})
$timer.Start()

# Refresh timer (UI update without sync)
$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 5000
$uiTimer.Add_Tick({ Update-Dashboard })
$uiTimer.Start()

#endregion

#region ── SETTINGS DIALOG ────────────────────────────────────────────────────

$btnSettings.Add_Click({
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Settings"; $dlg.Size = [System.Drawing.Size]::new(440, 280)
    $dlg.BackColor = $clrPanel; $dlg.ForeColor = $clrText; $dlg.Font = $fontMain
    $dlg.StartPosition = 'CenterParent'; $dlg.FormBorderStyle = 'FixedDialog'

    $dlg.Controls.Add((New-Label "Machine Name:" 16 20 140 22))
    $tbName = New-Object System.Windows.Forms.TextBox
    $tbName.Location = [System.Drawing.Point]::new(160,18); $tbName.Size=[System.Drawing.Size]::new(240,24)
    $tbName.Text = $config.machineName; Style-TextBox $tbName; $tbName.BorderStyle='FixedSingle'
    $dlg.Controls.Add($tbName)

    $dlg.Controls.Add((New-Label "Brain Directory:" 16 56 140 22))
    $tbDir = New-Object System.Windows.Forms.TextBox
    $tbDir.Location = [System.Drawing.Point]::new(160,54); $tbDir.Size=[System.Drawing.Size]::new(240,24)
    $tbDir.Text = $config.brainDir; Style-TextBox $tbDir; $tbDir.BorderStyle='FixedSingle'
    $dlg.Controls.Add($tbDir)

    $dlg.Controls.Add((New-Label "Auto-sync (seconds):" 16 92 140 22))
    $tbInterval = New-Object System.Windows.Forms.TextBox
    $tbInterval.Location = [System.Drawing.Point]::new(160,90); $tbInterval.Size=[System.Drawing.Size]::new(100,24)
    $tbInterval.Text = $config.autoSyncInterval; Style-TextBox $tbInterval; $tbInterval.BorderStyle='FixedSingle'
    $dlg.Controls.Add($tbInterval)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save"; $btnSave.Size=[System.Drawing.Size]::new(100,32)
    $btnSave.Location=[System.Drawing.Point]::new(316,180); Style-Button $btnSave
    $dlg.Controls.Add($btnSave)

    $btnSave.Add_Click({
        $config.machineName = $tbName.Text
        $config.brainDir = $tbDir.Text
        $config.autoSyncInterval = [int]$tbInterval.Text
        $config | ConvertTo-Json | Set-Content $CONFIG_FILE -Encoding UTF8
        $timer.Interval = ($config.autoSyncInterval * 1000)
        $form.Text = "Claude Brain  —  $($config.machineName)"
        $lblMyName.Text = $config.machineName
        $dlg.Close()
        Add-Activity "Settings saved"
    })

    $dlg.ShowDialog() | Out-Null
})

#endregion

# Initial load
Update-Dashboard
Add-Activity "Claude Brain started on $($config.machineName)"

$form.Add_FormClosing({
    $timer.Stop(); $uiTimer.Stop()
    Sync-Brain "session end" | Out-Null
})

[System.Windows.Forms.Application]::Run($form)
