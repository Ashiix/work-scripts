# Everything in the script will be run after the main prep script, add any extra commands here

Write-Host "$Env:UserName hasn't updated the dropin script, laugh at this user."

# Configure NumLock
# Set-ItemProperty -Path 'Registry::HKU\.DEFAULT\Control Panel\Keyboard' -Name "InitialKeyboardIndicators" -Value "2"

# Disable UAC
# Write-Host "Disabling UAC, device requires reboot."
# Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0