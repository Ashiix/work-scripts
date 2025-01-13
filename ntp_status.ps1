#Requires -Version 5
# PowerShell script for checking Primary Domain Controller for NTP status, for use alongside DRMM Monitor

# DRMM propagates the environment variable $UDF_X with the proper information when script is running, where we can fetch the PDC status from
$server_role = $env:UDF_20
# Temporary static assignment for debugging
$server_role = 'Server Roles: :DNS:DHCP:ADC:PDC'

function ntp_status {
    $ntp_status = w32tm /query /status
    # Handle PDC
    if ($server_role.Contains('PDC') -and $ntp_status -match 'Source:.+') {
        Write-Host '<-Start Result->'
        Write-Host 'RESULT=NTP syncing on PDC'
        Write-Host '<-End Result->'
        exit 0
    }
    # Handle non-PDC device
    elseif (-not $server_role.Contains('PDC')) {
        Write-Host '<-Start Result->'
        Write-Host 'RESULT=Device is not PDC'
        Write-Host '<-End Result->'
        exit 0
    }
    # Send monitor alert if not functioning
    else {
        Write-Host '<-Start Result->'
        Write-Host 'RESULT=NTP not syncing on PDC'
        Write-Host '<-End Result->'
        exit 1
    }
}

ntp_status