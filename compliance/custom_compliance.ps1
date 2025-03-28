#Requires -Version 5

$target_application = @('Datto EDR Agent')
$target_service = @('HUNTAgent', 'EndpointProtectionService')
$discovery_info = @{}

$target_application | ForEach-Object {
    $package = Get-Package -Name "$_" -ErrorAction SilentlyContinue
    if ($package) {
        $discovery_info += @{"$($package.Name)" = "$($package.Version)" }
    }
    else {
        $discovery_info += @{$_ = '0.0.0.0' }
    }
}
$target_service | ForEach-Object {
    $service_status = $(Get-Service -Name "$_" -ErrorAction SilentlyContinue).Status
    $discovery_info += @{$_ = $($service_status -eq 'Running') }
}

return $discovery_info | ConvertTo-Json -Compress