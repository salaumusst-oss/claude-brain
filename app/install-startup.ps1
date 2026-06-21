# Adds Claude Brain tray agent to Windows startup
$StartupFolder = [System.Environment]::GetFolderPath('Startup')
$ShortcutPath = "$StartupFolder\Claude Brain.lnk"
$TargetPath = (Resolve-Path "$PSScriptRoot\brain-tray.ps1").Path

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TargetPath`""
$Shortcut.WorkingDirectory = Split-Path $TargetPath
$Shortcut.WindowStyle = 7  # minimized
$Shortcut.Description = "Claude Brain Tray Agent"
$Shortcut.Save()

Write-Host "Claude Brain will now start automatically with Windows." -ForegroundColor Green
Write-Host "Shortcut created at: $ShortcutPath"
