# Claude Brain Setup Script for Windows
# Run this once on any new machine to join the brain network

param(
    [string]$MachineName = $env:COMPUTERNAME,
    [string]$CloneDir = "$env:USERPROFILE\claude-brain"
)

Write-Host "`n🧠 Claude Brain Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════" -ForegroundColor DarkGray

# 1. Clone if not already there
if (-not (Test-Path "$CloneDir\.git")) {
    Write-Host "`n[1/4] Cloning brain repo..." -ForegroundColor Yellow
    git clone https://github.com/salaumusst-oss/claude-brain.git $CloneDir
    if ($LASTEXITCODE -ne 0) { Write-Host "Clone failed. Check git credentials." -ForegroundColor Red; exit 1 }
} else {
    Write-Host "`n[1/4] Brain repo already cloned. Pulling latest..." -ForegroundColor Yellow
    git -C $CloneDir pull
}

# 2. Set git identity in repo
Write-Host "`n[2/4] Configuring git identity..." -ForegroundColor Yellow
git -C $CloneDir config user.email "salaumusst@gmail.com"
git -C $CloneDir config user.name $MachineName

# 3. Write app config for this machine
Write-Host "`n[3/4] Writing machine config..." -ForegroundColor Yellow
$config = @{
    machineName = $MachineName
    brainDir = $CloneDir
    autoSyncInterval = 60
} | ConvertTo-Json
$config | Set-Content "$CloneDir\app\config.json" -Encoding UTF8

# 4. Wire into Claude Code settings.json
Write-Host "`n[4/4] Configuring Claude Code auto-sync hook..." -ForegroundColor Yellow
$claudeSettings = "$env:USERPROFILE\.claude\settings.json"

if (Test-Path $claudeSettings) {
    $existing = Get-Content $claudeSettings | ConvertFrom-Json
} else {
    $existing = [PSCustomObject]@{}
    New-Item -ItemType Directory -Path (Split-Path $claudeSettings) -Force | Out-Null
}

$hookCmd = "powershell -NonInteractive -ExecutionPolicy Bypass -File `"$CloneDir\sync.ps1`" `"auto-sync`""

# Build hooks structure
$hook = [PSCustomObject]@{
    matcher = ""
    hooks = @([PSCustomObject]@{ type = "command"; command = $hookCmd })
}

if (-not $existing.PSObject.Properties['hooks']) {
    $existing | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{
        Stop = @($hook)
    })
} else {
    if (-not $existing.hooks.PSObject.Properties['Stop']) {
        $existing.hooks | Add-Member -NotePropertyName 'Stop' -NotePropertyValue @($hook)
    }
}

$existing | ConvertTo-Json -Depth 10 | Set-Content $claudeSettings -Encoding UTF8

# 5. Install startup shortcut
Write-Host "`nInstalling startup tray agent..." -ForegroundColor Yellow
& "$CloneDir\app\install-startup.ps1"

Write-Host "`n✓ Setup complete!" -ForegroundColor Green
Write-Host "  Machine name : $MachineName"
Write-Host "  Brain dir    : $CloneDir"
Write-Host "  Auto-sync    : on Claude Code stop"
Write-Host ""
Write-Host "To open the dashboard:" -ForegroundColor Cyan
Write-Host "  Double-click: $CloneDir\app\Launch Brain.bat"
Write-Host ""
Write-Host "To start the tray agent now:" -ForegroundColor Cyan
Write-Host "  $CloneDir\app\Start Tray Agent.bat"
