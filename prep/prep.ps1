# PowerShell script for prepping work machines
# Requires WDT scripts extracted to .\src\wdt\ (https://github.com/LeDragoX/Win-Debloat-Tools/tree/main/src/scripts)

# CONFIG
# Only installation method at present, may add a more sane one later
$hp_install_method = "bundle"

function Prep {
    # Handle directory generation
    $data_path = "$env:script_data_path\Prep"
    if (!(Test-Path $data_path)) {
        Write-Host "Data directory not found, creating now."
        New-Item $data_path -Type Directory
    }
    
    # Configure winget
    winget source update
    
    # Trust PSGallery 
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

    # Run Windows updates
    Write-Host "Installing PSWindowsUpdate module."
    Install-Module PSWindowsUpdate
    Write-Host "Checking for updates..."
    Get-WindowsUpdate
    Write-Host "installing updates..."
    Install-WindowsUpdate -AcceptAll

    # Debloat scripts
    $run_debloat = Read-Host 'Run debloat scripts? (Y/n)'
        if ($run_debloat.ToLower() -eq 'y') {
            .\src\wdt\Backup-System.ps1
        }
        else {
            Write-Host "Skipping debloat."
        }

    # Install vendor software 
    $oem = (Get-WmiObject -Class Win32_ComputerSystem -Property Manufacturer).Manufacturer
    Write-Host "Vendor identified as $oem. Proceeding with vendor software installation."
    # Handle HP machines
    # No official way to unattented install support assistant, using hacky method of extracting app bundle from installer executable
    # Executable can be found here > https://support.hp.com/us-en/help/hp-support-assistant
    if ($oem -eq "HP" -and $hp_install_method -eq "bundle") {
        Write-Host "Installing HP Support Assist using the extracted bundle method."
        Add-AppxPackage $data_path\hpsa.appxbundle
    }
    # Handle Lenovo machines
    # Sane install method, just uses winget
    elseif ($oem -eq "Lenovo") {
        Write-Host "Installing Lenovo Vantage using winget."
        winget install 9WZDNCRFJ4MV --force # MS Store code for Vantage
    }
    # Handle Dell machines
    # Sane install method, just uses installer executable
    elseif ($oem -eq "Dell") {
        Write-Host "Installing Dell SupportAssist using executable."
        .\$data_path\SupportAssistInstaller.exe /S
    }
    else {
        Write-Host "No matching software found for $oem. Proceeding with rest of configuration."
    }

    # Power settings configuration

    # Install DEDR

    # Install standard software
    # Chrome
    # Firefox
    # Reader

    # Run dropin script
    .\src\dropin.ps1
}

Prep


