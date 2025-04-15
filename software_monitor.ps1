#Requires -Version 5

# A generic application/process monitor (that in this case is) for detecting PURSS

# CONFIG
# N-Central/N-able, File Cache Service Agent, Solarwinds
# Any detection fields left empty will automatically default to being detected
# Note that all checks must pass for a target to be considered detected
[array]$targets = @(
    [PSCustomObject]@{
        Name        = 'TeamViewer'; # Primary TV client, can be used to connect FROM and TO
        Install_Dir = @('C:\Program Files\TeamViewer');
        Process     = @('TeamViewer_Service'); # The X vs W is intentional, ask TeamViewer, not me.
        Service     = @('TeamViewer'); # Only present on the full TeamViewer install
        Status      = ''
    },
    [PSCustomObject]@{
        Name        = 'TeamViewer QuickSupport'; # Seconary TV client, only used for connecting TO
        Install_Dir = @('C:\Users\*\AppData\Local\Temp\TeamViewer*');
        Process     = @('');
        Service     = @('');
        Status      = ''
    },
    [PSCustomObject]@{
        Name        = 'N-central Take Control';
        Install_Dir = 'C:\Users\*\AppData\Local\BeAnywhere Support Express';
        Process     = @('');
        Service     = @('')
        Status      = ''
    }
)
# ^ CONFIG ^


function Get-InstallState {
    param (
        [PSCustomObject]$target_object
    ) 
    # Bypass check if no directory is specified
    if ($target_object.Install_Dir[0] -eq '') {
        return $true
    }
    # Test all listed install directories
    $target_object.Install_Dir | ForEach-Object {
        if ($(Test-Path $_ -ErrorAction SilentlyContinue)) {
            return $true
        } 
    }
    return $false
}
function Get-ProcessState {
    param (
        [PSCustomObject]$target_object
    )
    # Bypass check if no process is specified
    if ($target_object.Process[0] -eq '') {
        return $true
    }
    $target_object.Process | ForEach-Object {
        if ($(Get-Process -Name $_ -ErrorAction SilentlyContinue)) {
            return $true
        }
    }
    return $false
}
function Get-ServiceState {
    param (
        [PSCustomObject]$target_object
    )
    # Bypass check if no service is specified
    if ($target_object.Service[0] -eq '') {
        return $true
    }
    $target_object.Service | ForEach-Object {
        if ($(Get-Service -Name $_ -ErrorAction SilentlyContinue)) {
            return $true
        }
    }
    return $false
}

function software_monitor {
    param (
        [array]$targets
    )
    $targets | ForEach-Object {
        if ($(Get-InstallState $_) -and $(Get-ServiceState $_) -and $(Get-ProcessState $_)) {
            $_.Status = 'Detected'
        }
    }
    
    $targets | ForEach-Object {
        Write-Output "$($_.Name): $($_.Status)"
    }
}

software_monitor $targets