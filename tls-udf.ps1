# Prevent running partial script
function TLS_UDF {
# HANDLE PROTOCOLS
# Get list of existing protocol keys
$protocol_keys = ""
# Navigate to the protocol registry entries
Set-Location -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"
# Iterate thru and extract key name
Get-ChildItem -Path . | ForEach-Object {
    $protocol_keys = "$($protocol_keys.Trim())$($_.Name.Split('\')[-1])|"
}
# Remove trailing |
$protocol_keys = "$($protocol_keys[0..($protocol_keys.Length-2)] -join '')"
# Extract list of enabled protocols from the previously generated list
$enabled_protocols = ""
# Iterate thru gathered keys to check if they are enabled
$protocol_keys.Split('|') | ForEach-Object {
    if (-not ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$($_)\Client").Enabled) -eq 0) {
        $enabled_protocols = "$($enabled_protocols.Trim())$($_)|"
    }
}
# Remove trailing |
$enabled_protocols = "$($enabled_protocols[0..($enabled_protocols.Length-2)] -join '')"

# HANDLE CIPHERS
# Get list of cipher keys
$cipher_keys = ""
# Navigate to the cipher registry entries
Set-Location -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers"
# Iterate thru and extract key name
Get-ChildItem -Path . | ForEach-Object {
    $cipher_keys = "$($cipher_keys.Trim())$($_.Name.Split('\')[-1])|"
}
# Remove trailing |
$cipher_keys = "$($cipher_keys[0..($cipher_keys.Length-2)] -join '')"
# Extract list of enabled ciphers from the previously generated list
$enabled_ciphers = ""
# Iterate thru gathered keys to check if they are enabled
$cipher_keys.Split('|') | ForEach-Object {
    if (-not ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\$($_)").Enabled) -eq 0) {
        $enabled_ciphers = "$($enabled_ciphers.Trim())$($_)|"
    }
}
# Remove trailing |
$enabled_ciphers = "$($enabled_ciphers[0..($enabled_ciphers.Length-2)] -join '')"

# Create new UDF string from existing strings
$udf_string = "Enabled protocols: $($enabled_protocols)     Enabled ciphers: $($enabled_ciphers)"
$udf_string
# Update UDF
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom27" /t REG_SZ /d $udf_string /f
}
# Run
TLS_UDF