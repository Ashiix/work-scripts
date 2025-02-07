# PowerShell script for prepping work machines
# Requires WDT src extracted to .\src\wdt\ (https://github.com/LeDragoX/Win-Debloat-Tools/tree/main/src/scripts)

# CONFIG
# Only installation method at present, may add a more sane one later
$hp_install_method = 'bundle'
# ^ CONFIG ^

function Prep {
    # Initialize static variables
    #$wdt_dir = '.\src\wdt\scripts\'

    # Handle directory generation
    $data_path = "$env:script_data_path\Prep"
    if (!(Test-Path $data_path)) {
        Write-Host 'Data directory not found, creating now.'
        New-Item $data_path -Type Directory
    }
    
    # Configure winget
    winget source update
    
    # Trust PSGallery 
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

    # Run Windows updates
    Write-Host 'Installing PSWindowsUpdate module.'
    Install-Module PSWindowsUpdate
    Write-Host 'Checking for updates...'
    Get-WindowsUpdate
    Write-Host 'installing updates...'
    Install-WindowsUpdate -AcceptAll

    # Debloat scripts
    $run_debloat = Read-Host 'Run debloat scripts? (Y/n)'
    if ($run_debloat.ToLower() -eq 'y' -or $run_debloat -eq '') {
        # Set execution policy
        Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
        Get-ChildItem -Recurse *.ps*1 | Unblock-File
        # Creates system restore point before any tweaks are run (SAFE)
        .\src\wdt\scripts\Backup-System.ps1
        # Remove all Xbox software and services (SAFE)
        .\src\wdt\scripts\Remove-Xbox.ps1
        # Disables invasive telemetry that does not impact the user (SAFE)
        .\src\wdt\scripts\Optimize-Privacy.ps1
        # Improves performance by making small tweaks to scheduling, running services, and other bloat (SAFE)
        .\src\wdt\scripts\Optimize-Performance.ps1
        .\src\wdt\scripts\Optimize-TaskScheduler.ps1
        # Removes default software bloat, including things like News, Get Help, and My Phone
        $run_sw_bloat_removal = Read-Host 'Run software deblot? (Y/n)'
        if ($run_sw_bloat_removal.ToLower() -eq 'y' -or $run_sw_bloat_removal -eq '') {
            .\src\wdt\scripts\Invoke-DebloatSoftware.ps1
            .\src\wdt\scripts\Remove-BloatwareAppsList.ps1
        }
        else {
            Write-Host 'Tech requested not to perform software debloat, skipping.'
        }
        $run_repair = Read-Host 'Run system repair? (Y/n)'
        if ($run_repair.ToLower() -eq 'y' -or $run_repair -eq '') {
            # Fix common issues with freshly installed systems (SAFE, BUT WILL TAKE A WHILE)
            Write-Host 'Running repair.'
            .\src\wdt\scripts\Repair-WindowsSystem.ps1
        }
        else {
            Write-Host 'Tech requested not to perform system repair, skipping.'
        }

    }
    else {
        Write-Host 'Tech requested not to perform any debloat options, Skipping.'
    }

    # Install vendor software 
    $oem = (Get-WmiObject -Class Win32_ComputerSystem -Property Manufacturer).Manufacturer
    Write-Host "Vendor identified as $oem. Proceeding with vendor software installation."
    # Handle HP machines
    # No official way to unattented install support assistant, using hacky method of extracting app bundle from installer executable
    # Executable can be found here > https://support.hp.com/us-en/help/hp-support-assistant
    if ($oem -eq 'HP' -and $hp_install_method -eq 'bundle') {
        Write-Host 'Installing HP Support Assist using the extracted bundle method.'
        Add-AppxPackage $data_path\hpsa.appxbundle
    }
    # Handle Lenovo machines
    # Sane install method, just uses winget
    elseif ($oem -eq 'Lenovo') {
        Write-Host 'Installing Lenovo Vantage using winget.'
        winget install 9WZDNCRFJ4MV --force # MS Store code for Vantage
    }
    # Handle Dell machines
    # Sane install method, just uses installer executable
    elseif ($oem -eq 'Dell') {
        Write-Host 'Installing Dell SupportAssist using executable.'
        #TODO: install Dell Command Update as well
        .\$data_path\SupportAssistInstaller.exe /S
    }
    else {
        Write-Host "No matching software found for $oem. Proceeding with rest of configuration."
    }

    # Power settings configuration
    
    $laptop_types = @(8, 9, 10, 14)
    if ($laptop_types.Contains([int](Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes[0])) {
        Write-Host 'Chassis type identified as a laptop, configuring power settings as such.'
    }
    else {
        Write-Host 'Chassis type identified as a desktop, configuring power settings as such.'
        powercfg.exe -SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c # Identifier for the "High Performance" power plan
    }
    Write-Host $is_laptop

    # Install DEDR

    # Install standard software
    # Chrome
    # Firefox
    # Reader

    # Run dropin script
    .\src\dropin.ps1
}

Prep


