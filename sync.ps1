# Claude Brain Sync â€” run this to push/pull shared memory
param(
    [string]$Message = "sync"
)

$BrainDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $BrainDir

git pull origin main 2>&1 | Write-Host

$status = git status --porcelain
if ($status) {
    git add -A
    git commit -m "$Message $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin main 2>&1 | Write-Host
    Write-Host "Brain synced." -ForegroundColor Green
} else {
    Write-Host "Brain up to date." -ForegroundColor Cyan
}

