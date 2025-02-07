function Remove-OneStart {
    Stop-Process -Name 'onestart' -Force -ErrorAction SilentlyContinue # Stop all OneStart services
    Remove-Item -Path 'C:\Windows\Prefetch\ONESTART*' -Force # File remnants caught by BCUninstaller
    Remove-Item -Path 'C:\Users\*\AppData\Local\Onestart.ai\' -Recurse -Force # Application install directory
    Remove-Item -Path 'C:\Users\*\Desktop\OneStart.lnk' -Force # Desktop shortcut
    Remove-Item -Path 'C:\Users\*\Desktop\Manuals.lnk' -Force # Second shortcut
    Remove-Item -Path 'C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneStart.lnk' -Force # Start menu shortcut
    Remove-Item HKCU:\Software\OneStart.ai -Recurse # Remove OneStart regkeys
}
Remove-OneStart