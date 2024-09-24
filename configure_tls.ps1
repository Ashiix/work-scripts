# PowerShell script that enabled enables TLS 1.2, sets it as the default for the .NET version ADSync uses, 
# and updates the selected UDF with details on it's configuration

# Script must be run as a user with system access


# CONFIG
# Override the reboot environment variable set by the Datto component, also useful if running outside a component
$reboot_override = $false
# UDF to save data to; must be changed to target UDF
$udf = "Custom27"
# ^ CONFIG ^




# Handle key entries
function verify_keys {
    # Keep track of how many keys already exist while creating ones that don't
    $existing_keys = 0
    # TLS 1.2 key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2" -ErrorAction Stop }
    catch { $existing_keys++ }
    # Server key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -ErrorAction Stop }
    catch { $existing_keys++ }
    # Client key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -ErrorAction Stop }
    catch { $existing_keys++ }
    # .NET key
    try { New-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -ErrorAction Stop }
    catch { $existing_keys++ }
    # .NET x86 key
    try { New-Item "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" -ErrorAction Stop }
    catch { $existing_keys++ }
    # Return how many keys already existed
    return $existing_keys
}

# Handle value entries
function verify_values {
    # Keep track of how many values already match target while setting ones that don't
    $existing_values = 0

    # Server values
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"    
    if (-not ((Get-ItemProperty -Path $path).Enabled -eq 1)) {
        Set-ItemProperty -Path $path -Name "Enabled" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }
    if (-not ((Get-ItemProperty -Path $path).DisabledByDefault -eq 0)) {
        Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value '0' -Type "DWord"
    }
    else { $existing_values++ }

    # Client values
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"    
    if (-not ((Get-ItemProperty -Path $path).Enabled -eq 1)) {
        Set-ItemProperty -Path $path -Name "Enabled" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }
    if (-not ((Get-ItemProperty -Path $path).DisabledByDefault -eq 0)) {
        Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value '0' -Type "DWord"
    }
    else { $existing_values++ }

    # .NET values
    $path = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"    
    if (-not ((Get-ItemProperty -Path $path).SystemDefaultTlsVersions -eq 1)) {
        Set-ItemProperty -Path $path -Name "SystemDefaultTlsVersions" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }
    if (-not ((Get-ItemProperty -Path $path).SchUseStrongCrypto -eq 1)) {
        Set-ItemProperty -Path $path -Name "SchUseStrongCrypto" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }

    # .NET x86 values
    $path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"    
    if (-not ((Get-ItemProperty -Path $path).SystemDefaultTlsVersions -eq 1)) {
        Set-ItemProperty -Path $path -Name "SystemDefaultTlsVersions" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }
    if (-not ((Get-ItemProperty -Path $path).SchUseStrongCrypto -eq 1)) {
        Set-ItemProperty -Path $path -Name "SchUseStrongCrypto" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }

    # Return how many keys already existed
    return $existing_values
}

function update_udf {
    $bad_values = ""

    # Server values
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"    
    if (-not ((Get-ItemProperty -Path $path).Enabled -eq 1)) {
        $bad_values += "S_Enabled | "
    }
    if (-not ((Get-ItemProperty -Path $path).DisabledByDefault -eq 0)) {
        $bad_values += "S_DBD | "
    }

    # Client values
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"    
    if (-not ((Get-ItemProperty -Path $path).Enabled -eq 1)) {
        $bad_values += "C_Enabled | "
    }
    if (-not ((Get-ItemProperty -Path $path).DisabledByDefault -eq 0)) {
        $bad_values += "C_DBD | "
    }

    # .NET values
    $path = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"    
    if (-not ((Get-ItemProperty -Path $path).SystemDefaultTlsVersions -eq 1)) {
        $bad_values += ".N_TLS | "
    }
    if (-not ((Get-ItemProperty -Path $path).SchUseStrongCrypto -eq 1)) {
        $bad_values += ".N_SC | "
    }

    # .NET x86 values
    $path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"    
    if (-not ((Get-ItemProperty -Path $path).SystemDefaultTlsVersions -eq 1)) {
        $bad_values += ".N_x86_TLS | "
    }
    if (-not ((Get-ItemProperty -Path $path).SchUseStrongCrypto -eq 1)) {
        $bad_values += ".N_x86_SC | "
    }

    # Create UDF string
    if ($bad_values.Length -eq 0) {
        $udf_string = "TLS 1.2 properly configured"
    }
    else {
        $udf_string = "Values misconfigured: $(($bad_values[0..($bad_values.Length-3)]) -join '')"
    }

    # Update UDF
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $udf /t REG_SZ /d "$($udf_string)" /f
}

function configure_tls {
    # Handle reboot override setting
    if ($reboot_override) {
        $env:schedule_reboot = $true
    }
    # Only proceed with script of ADSync is both installed and running
    Write-Host "Checking ADSync status..."
    try {
        $sync_state = (Get-Service "ADSync" -ErrorAction Stop | Select-Object Status) 
        $sync_state = [bool]($sync_state -match "Running")
        if ($sync_state) { Write-Output "ADSync installed and running, proceeding with configuration." }
        else {
            Write-Output "ADSync installed but not running, no need to configure: exiting."
            exit 0
        }
    }
    catch {
        Write-Host "ADSync not installed on machine, no need to configure: exiting"
        exit 0
    }

    Write-Host "Checking status of registry keys..."
    $existing_keys = verify_keys
    Write-Host "Done.`r`nChecking status of registry values..."
    $existing_values = verify_values
    Write-Host "Done."
    if (($existing_keys -eq 5) -and ($existing_values -eq 8)) {
        Write-Host "TLS 1.2 is already configured on this machine, no reboot required."
    }
    else {
        Write-Host "TLS 1.2 successfully configured, reboot required for changes to take effect."
        if ($env:schedule_reboot) {
            Write-Host "Automatically scheduling reboot."
            $epoch = [System.DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
            $target = (([int](($epoch / 86400))) * 86400) # No need to add any time as we are UTC-4, reboot will be scheduled for same day at 8 PM
            $delay = $target - $epoch
            shutdown.exe /r /t $delay
        }
        else {
            Write-Host "Automatic scheduling disabled."
        }
    }

    Write-Host "Updating UDF..."
    update_udf
}

configure_tls