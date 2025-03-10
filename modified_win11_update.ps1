<# windows 11 upgrade tool :: REDUX build 3c/seagull, january 2024
   user variables: usrOverrideChecks/boolean

   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM is the one exception to this rule.
   	
   the moment you edit this script it becomes your own risk and support will not provide assistance with it.

########################################## FUNCTION ZONE ###############################################>

$varScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function verifyPackage ($file, $certificate, $thumbprint, $name, $url) {
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | Out-Null
    }
    catch [System.Management.Automation.MethodInvocationException] {
        Write-Host "! ERROR: $name installer did not contain a valid digital certificate."
        Write-Host "  This could suggest a change in the way $name is packaged; it could"
        Write-Host '  also suggest tampering in the connection chain.'
        Write-Host "- Please ensure $url is whitelisted and try again."
        Write-Host '  If this issue persists across different devices, please file a support ticket.'
    }

    $varIntermediate = ($varChain.ChainElements | ForEach-Object { $_.Certificate } | Where-Object { $_.Subject -match "$certificate" }).Thumbprint

    if ($varIntermediate -ne $thumbprint) {
        Write-Host "! ERROR: $file did not pass verification checks for its digital signature."
        Write-Host "  This could suggest that the certificate used to sign the $name installer"
        Write-Host '  has changed; it could also suggest tampering in the connection chain.'
        Write-Host `r
        if ($varIntermediate) {
            Write-Host ": We received: $varIntermediate"
            Write-Host "  We expected: $thumbprint"
            Write-Host '  Please report this issue.'
        }
        Write-Host '- Installation cannot continue. Exiting.'
        exit 1
    }
    else {
        Write-Host '- Digital Signature verification passed.'
    }
}

function downloadShortlink ($url, $whitelist, $filename) {
    #custom :: seagull, datto inc.
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    $req = [System.Net.HttpWebRequest]::Create("$url")
    $req.Method = 'HEAD'
    $response = $req.GetResponse()
    $varLongLink = $response.ResponseURI.AbsoluteURI
    (New-Object System.Net.WebClient).DownloadFile("$varLongLink", "$filename")
    $response.close()
    if (!(Test-Path $filename)) {
        Write-Host "! ERROR: File $varfilename could not be downloaded."
        Write-Host "  Please ensure you are whitelisting $whitelist."
        Write-Host '- Operations cannot continue; exiting.'
        #exit 1
    }
    else {
        Write-Host "- Downloaded (as $($filename.split('\\')[-1])) from URL:"
        Write-Host "  $varLongLink"
    }
}

function quitOr {
    if ($env:usrOverrideChecks -match 'true') {
        Write-Host '! This is a blocking error and should abort the process; however, the usrOverrideChecks'
        Write-Host '  flag has been enabled, and the error will thus be ignored.'
        Write-Host '  Support will not be able to assist with issues that arise as a consequence of this action.'
    }
    else {
        Write-Host '! This is a blocking error; the operation has been aborted.'
        Write-Host '  If you do not believe the error to be valid, you can re-run this Component with the'
        Write-Host "  `'usrOverrideChecks`' flag enabled, which will ignore blocking errors and proceed."
        Write-Host '  Support will not be able to assist with issues that arise as a consequence of this action.'
        Stop-Process -Name setupHost -ErrorAction SilentlyContinue
        Stop-Process -Name mediaTool -ErrorAction SilentlyContinue
        exit 1
    }
}

[int]$varWinver = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber).CurrentBuildNumber
[int]$varLangCode = cmd /c set /a 0x$((Get-ItemProperty hklm:\system\controlset001\control\nls\language -Name InstallLanguage).InstallLanguage)
[int]$varSKU = (Get-WmiObject -Class win32_operatingsystem -Property OperatingSystemSKU).OperatingSystemSKU

############################################ CODE ZONE #################################################

Write-Host 'Windows 11 Updater: Update any Windows 10+ device to the latest version of Windows 11'
Write-Host '==============================================================================='
Write-Host '- Device information:'
Write-Host ": Hostname:        $env:COMPUTERNAME"
Write-Host ": Windows Build:   $varWinver"
Write-Host ": Windows Edition: $((Get-WmiObject -ComputerName $env:computername -Class win32_operatingSystem).caption)"
Write-Host ": System Language: $(([system.globalization.cultureinfo]::GetCultures('AllCultures') | Where-Object {$_.LCID -eq $varLangCode}).DisplayName)"
if ($env:usrOverrideChecks -match 'true') {
    Write-Host '! User has enabled overriding outcomes of script errors - proceed with caution'
}
else {
    Write-Host ': Script errors will abort execution as intended (this can be overridden)'
}
Write-Host '- The Component will run the Windows 11 Installation Assistant on the device'
Write-Host '  and use the disk image it downloads to install Windows 11 on this device.'
Write-Host '==============================================================================='

#################### SUBZONE: DEVICE ELIGIBILITY

#windows edition
if ((4, 27, 48, 49, 98, 99, 100, 101, 161, 162) | Where-Object { $_ -eq $varSKU }) {
    Write-Host "- Device Windows SKU ($varSKU) is supported."
}
else {
    Write-Host "! ERROR: Device Windows SKU ($varSKU) not supported."
    Write-Host '  Please proceed only if you are certain the Edition of Windows currently'
    Write-Host '  running on the endpoint is compatible with this installation method.'
    quitOr
}

#services pipe timeout
REG ADD 'HKLM\SYSTEM\CurrentControlSet\Control' /v ServicesPipeTimeout /t REG_DWORD /d '300000' /f 2>&1>$null
Write-Host '- Device service timeout period configured to five minutes.'

#architecture
if ((Get-WmiObject -Class Win32_Processor).Architecture -ne 9) {
    Write-Host '! ERROR: This device does not have an AMD64/EM64T-capable processor.'
    Write-Host '  Windows 11 will not run on 32-bit devices.'
    Write-Host '  Installation cancelled; exiting.'
    exit 1
}
elseif ([intptr]::Size -eq 4) {
    Write-Host ': 32-bit Windows detected, but device processor is AMD64/EM64T-capable.'
    Write-Host '  An architecture upgrade will be attempted; the device will lose'
    Write-Host '  the ability to run 16-bit programs, but 32-bit programs will'
    Write-Host '  continue to work using Windows-on-Windows (WOW) emulation.'
}
else {
    Write-Host '- 64-bit architecture checks passed.'
}

#minimum W10 2004
if ($varWinver -lt 19041) {
    Write-Host '! ERROR: Windows 10 version 2004 or higher is required to proceed.'
    exit 1
}
else {
    Write-Host '- Windows version check passed.'
}

#licence check
if ((Get-WmiObject SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -And $_.Name -Like '*Windows(R)*' } | Select-Object -First 1).LicenseStatus -ne 1) {
    Write-Host '! ERROR: Windows 11 can only be installed on devices with an active Windows licence.'
    quitOr
}
else {
    Write-Host '- Windows licence is valid.'
}

#make sure we have enough disk space - installation plus iso hosting
$varSysFree = [Math]::Round((Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveLetter -eq $env:SystemDrive } | Select-Object -expand FreeSpace) / 1GB)
if ($varSysFree -lt 20) {
    Write-Host '! ERROR: System drive requires at least 20GB: 13 for installation, 7 for the disc image.'
    quitOr
}
else {
    Write-Host '- Device has at least 20GB free hard disk space.'
}

#check for RAM
if (((Get-WmiObject -Class 'cim_physicalmemory' | Measure-Object -Property Capacity -Sum).Sum / 1024 / 1024 / 1024) -lt 4) {
    Write-Host '! ERROR: This machine may not have enough RAM installed.'
    Write-Host '  Windows 11 requires at least 4GB of system RAM to be installed.'
    Write-Host "  In case of errors, please check this device's RAM."
    quitOr
}
else {
    Write-Host '- Device has at least 4GB of RAM installed.'
}

#TPM check
$varTPM = @(0, 0, 0) # present :: enabled :: activated
if ((Get-WmiObject -Class Win32_TPM -EnableAllPrivileges -Namespace 'root\CIMV2\Security\MicrosoftTpm').__SERVER) {
    # TPM installed
    $varTPM[0] = 1
    if ((Get-WmiObject -Namespace ROOT\CIMV2\Security\MicrosoftTpm -Class Win32_Tpm).IsEnabled().isenabled -eq $true) {
        # TPM enabled
        $varTPM[1] = 1
        if ((Get-WmiObject -Namespace ROOT\CIMV2\Security\MicrosoftTpm -Class Win32_Tpm).IsActivated().isactivated -eq $true) {
            # TPM activated
            $varTPM[2] = 1
        }
        else {
            $varTPM[2] = 0
        }
    }
    else {
        $varTPM[1] = 0
        $varTPM[2] = 0
    }
}

switch -Regex ($varTPM -as [string]) {
    '^0' {
        Write-Host '! ERROR: This system does not contain a Trusted Platform Module (TPM).'
        Write-Host '  Windows 11 requires the use of a TPM to install.'
        Write-Host '  Your device may contain a firmware TPM (fTPM) which can be enabled in the BIOS/uEFI settings. More info:'
        Write-Host '  https://support.microsoft.com/en-us/windows/enable-tpm-2-0-on-your-pc-1fd5a332-360d-4f46-a1e7-ae6b0c90645c'
        Write-Host '- Cannot continue; exiting.'
        quitOr
    } '0 0$' {
        Write-Host '! ERROR: Whilst a TPM was detected in this system, the WMI reports that it is disabled.'
        Write-Host '  Please re-enable the use of the TPM and try installing again.'
        Write-Host '- Cannot continue; exiting.'
        quitOr
    } default {
        Write-Host '! ERROR: Whilst a TPM was detected in this system, the WMI reports that it has been deactivated.'
        Write-Host '  Please re-activate the TPM and try installing again.'
        Write-Host '- Cannot continue; exiting.'
        quitOr
    } '1$' {
        Write-Host '- TPM installed and active.'
    } $null {
        Write-Host '! ERROR: A fault has occurred during the TPM checking subroutine. Please report this.' 
        quitOr
    }

    # to those who read my scripts: this logic is taken from the "bitlocker & TPM audit" component, which offers a much more in-depth
    # look at a device's bitlocker/TPM status than is offered here. grab it from the comstore today! -- seagull
}

#previous installation?
if (Test-Path "$env:SystemDrive\`$WINDOWS.~WS") {
    Remove-Item -Path "$env:SystemDrive\`$WINDOWS.~WS" -Recurse -Force
    Remove-Item -Path "$env:SystemDrive\`$WINDOWS.~WS" -Recurse -Force
    Write-Host `r
    Write-Host 'Deleting WINDOWS.~WS directory'
    Write-Host `r
}

Write-Host '==============================================================================='
downloadShortlink 'https://go.microsoft.com/fwlink/?linkid=2171764' 'https://download.microsoft.com' "$varScriptDir\installAssistant.exe"
verifyPackage "$varScriptDir\installAssistant.exe" 'Microsoft Code Signing PCA' 'F252E794FE438E35ACE6E53762C0A234A2C52135' 'Microsoft Update Assistant' 'https://download.microsoft.com'

#kick off the update
Start-Process "$varScriptDir\installAssistant.exe" -ArgumentList '/quietinstall /skipeula /auto upgrade'
#make sure it's done something
Start-Sleep -Seconds 120

<#
    looking to add an option to stop the device from rebooting automatically?
    unfortunately the tool we're using, the windows 11 install assistant, lacks such a flag.
    the flags we use above - "/quietinstall /skipeula /auto upgrade" - are the only useful flags we could find.
    naturally the documentation for this is poor, but there is no indication of any reboot option.
    https://superuser.com/questions/1681291/command-line-options-for-windows-11-installation-assistant
    (there is "norestartUI" but that doesn't do what you'd think it does.)

    - seagull, january 2024
#>

#lookup UA configuration.ini for ESD download location :: jim d., datto labs
$updateConfigINI = "${env:ProgramFiles(x86)}\WindowsInstallationAssistant\Configuration.ini" #config.ini contains download path
If (!(Test-Path $updateConfigINI)) {
    Write-Host '! ERROR: Configuration.ini not found. Installation Assistant has likely suffered an error.' #previous failed UA install attempt can leave UA directory in a broken state. ETL file permission/ownership cannot be regained and ini cannot be rewritten.
    Write-Host '  Please attend to the device directly.'
    Write-Host '  The device may require further attention or an ISO based install.'
    Write-Host '- Setup process aborted.'
    Stop-Process -Name Windows10UpgraderApp -ErrorAction SilentlyContinue -Force #you'd think it'd be Windows11UpgraderApp, but it isn't
    Stop-Process -Name installAssistant -ErrorAction SilentlyContinue -Force
    exit 1 
}
else {
    $select = Select-String -Path $updateConfigINI -Pattern 'DownloadESDFolder' | Select-Object line
    $DownloadESDFolder = $select.Line.Split('=')[1]
    if (!(Test-Path "$DownloadESDFolder*.esd")) {
        Write-Host '! ERROR: Could not confirm that an ESD is being downloaded.'
        Write-Host '  This usually means that the device does not see itself as requiring an update.'
        Write-Host '  Please attend to the device directly; it may require further attention.'
        Write-Host '- Setup process aborted.'
        Stop-Process -Name Windows10UpgraderApp -ErrorAction SilentlyContinue -Force #again, not a typo
        Stop-Process -Name installAssistant -ErrorAction SilentlyContinue -Force
        exit 1
    }
    else {
        ## Check ESD file activity is valid and current
        $hours_to_check = $(Get-Date).AddMinutes(-10)
        Get-Item $DownloadESDFolder*.esd | Where-Object { $_.LastWriteTime -gt $hours_to_check } -OutVariable esdValid | ForEach-Object { Write-Host ": ESD: $DownloadESDFolder$($_.Name)" }
        If ($esdValid.count -eq 0) {
            Write-Host '! NOTICE: The script was unable to confirm that Windows 11 setup files are being downloaded.'
            Write-Host '  This may indicate a simple delay; it may alternatively suggest greater issues.'
            Write-Host '  Please allow the endpoint an hour before inspecting it. An active installation can be noted'
            Write-Host "  by the presence of an ESD file in $DownloadESDFolder; if there is no such file, please"
            Write-Host '  consider running the Update Assistant manually on the device to see if any errors arise.'
            exit 1
        }
    }
}

Write-Host '- The Windows 11 Setup executable has been instructed to begin installation.'
Write-Host '  This Component has performed its job and will retire, but the task is still ongoing;'
Write-Host '  if errors occur with the installation process, they will require user attention.'
Write-Host "  Installation logs are populated into '$env:SystemDrive\`$Windows.~bt\Sources'."
Write-Host '  (Make sure the ESD has been downloaded and the installation has failed before checking!)'
Write-Host `r
Write-Host '  The device should reboot automatically but this may take several hours.'