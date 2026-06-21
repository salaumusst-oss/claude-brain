# Adds Claude Brain aliases to your PowerShell profile
# Run once: powershell -ExecutionPolicy Bypass -File add-aliases.ps1

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$PROFILE_PATH = $PROFILE.CurrentUserAllHosts

if (-not (Test-Path $PROFILE_PATH)) {
    New-Item -ItemType File -Path $PROFILE_PATH -Force | Out-Null
}

# Build alias block using string concat to avoid here-string quoting issues
$nl = [System.Environment]::NewLine
$q = '"'
$bd = $BRAIN_DIR

$aliases = $nl +
    "# -- Claude Brain --" + $nl +
    ('$_BRAIN = ' + $q + $bd + $q) + $nl +
    ('function brain        { Start-Process powershell -ArgumentList ' + $q + '-NoProfile -ExecutionPolicy Bypass -File $_BRAIN\app\brain.ps1' + $q + ' -WindowStyle Hidden }') + $nl +
    ('function brain-web    { & powershell -NoProfile -ExecutionPolicy Bypass -File "$_BRAIN\app\brain-web.ps1" }') + $nl +
    ('function brain-sync   { & powershell -NonInteractive -ExecutionPolicy Bypass -File "$_BRAIN\sync.ps1" $args }') + $nl +
    ('function brain-switch { & powershell -ExecutionPolicy Bypass -File "$_BRAIN\scripts\switch.ps1" $args }') + $nl +
    ('function brain-snap   { & powershell -ExecutionPolicy Bypass -File "$_BRAIN\scripts\snapshot.ps1" $args }') + $nl +
    ('function brain-status { git -C "$_BRAIN" status; git -C "$_BRAIN" log --oneline -5 }') + $nl +
    ('function brain-inbox  { Get-ChildItem "$_BRAIN\inbox" -Filter "*.md" | Where-Object { $_.Name -ne "README.md" } | Format-Table Name, LastWriteTime }') + $nl +
    "# -------------------" + $nl

$existing = Get-Content $PROFILE_PATH -Raw -ErrorAction SilentlyContinue
if ($existing -match "Claude Brain") {
    Write-Host "Brain aliases already in profile." -ForegroundColor Yellow
} else {
    Add-Content $PROFILE_PATH $aliases -Encoding UTF8
    Write-Host "Brain aliases added to: $PROFILE_PATH" -ForegroundColor Green
    Write-Host "Restart PowerShell or run: . `$PROFILE" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Commands: brain, brain-web, brain-sync, brain-switch, brain-snap, brain-status, brain-inbox" -ForegroundColor Cyan
}
