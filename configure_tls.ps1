# Handle key entries
function verify_keys {
    # Keep track of how many keys already exist while creating ones that don't
    $existing_keys = 0
    # TLS 1.2 key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2" -ErrorAction Stop | Out-Null }
    catch { $existing_keys++ }
    # Server key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -ErrorAction Stop | Out-Null }
    catch { $existing_keys++ }
    # Client key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -ErrorAction Stop | Out-Null }
    catch { $existing_keys++ }
    # .NET key
    try { New-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -ErrorAction Stop | Out-Null }
    catch { $existing_keys++ }
    # .NET Node key
    try { New-Item "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" -ErrorAction Stop | Out-Null }
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

    # .NET Node values
    $path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"    
    if (-not ((Get-ItemProperty -Path $path).SystemDefaultTlsVersions -eq 1)) {
        Set-ItemProperty -Path $path -Name "SystemDefaultTlsVersions" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }
    if (-not ((Get-ItemProperty -Path $path).SchUseStrongCrypto -eq 1)) {
        Set-ItemProperty -Path $path -Name "SchUseStrongCrypto" -Value '1' -Type "DWord"
    }
    else { $existing_values++ }

    # # Return how many values already exist
    return $existing_values
}

function configure_tls {
    $existing_keys = verify_keys
    $existing_values = verify_values
    if (($existing_keys -eq 5) -and ($existing_values -eq 8)) {
        Write-Host
    }
    Write-Host "Existing keys: $($existing_keys)`r`nExisting values: $($existing_values)"
}

configure_tls