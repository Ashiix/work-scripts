# return ($(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server").Enabled -eq 1)

# Handle key entries
function verify_keys {
    # Keep track of how many keys already exist while creating ones that don't
    $existing_keys = 0
    # TLS 1.2 key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2" -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "TLS 1.2 key already exists, skipping." 
        $existing_keys++
    }
    # Server key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "Server key already exists, skipping." 
        $existing_keys++
    }
    # Client key
    try { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "Client key already exists, skipping." 
        $existing_keys++
    }
    # .NET key
    try { New-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -ErrorAction Stop | Out-Null }
    catch {
        Write-Host ".NET key already exists, skipping."
        $existing_keys++ 
    }
    # .NET Node key
    try { New-Item "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" -ErrorAction Stop | Out-Null }
    catch {
        Write-Host ".NET Node key already exists, skipping."
        $existing_keys++ 
    }
    # Return how many keys already existed
    return $existing_keys
}

# Handle value entries
function verify_values {
    # Keep track of how many values already exist while creating ones that don't
    $existing_values = 0
    # Server values
    # Client values
    # .NET values
    # .NET Node values
    return $existing_values
}







function configure_tls {
    # If 1.2 is not enabled, enable it and schedule reboot
    # Write-Output "Checking status of TLS 1.2..."
    # if (-not $(is_tls12_enabled)) {
    #     Write-Output "Status reported as disabled, proceeding to enable."
    # }
    # else {
    #     Write-Output "Status reported as enabled, exiting script."
    #     exit 0
    # }
    $existing_keys = verify_keys
    $existing_values = verify_values
    Write-Host "Existing keys: $($existing_keys)`r`nExisting values: $($existing_values)"
}

configure_tls