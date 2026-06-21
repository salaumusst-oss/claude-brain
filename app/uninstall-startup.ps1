# Removes Claude Brain from Windows startup
$StartupFolder = [System.Environment]::GetFolderPath('Startup')
$ShortcutPath = "$StartupFolder\Claude Brain.lnk"
if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host "Claude Brain removed from startup." -ForegroundColor Yellow
} else {
    Write-Host "Claude Brain was not in startup." -ForegroundColor Gray
}
