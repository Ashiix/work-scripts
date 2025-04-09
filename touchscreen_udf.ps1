$udf_string = 'No touchscreen found.'
if (Get-CimInstance -Class CIM_PointingDevice | Where-Object { $_.PointingType -eq 8 }) {
    Write-Output 'Touchscreen found as PointingType 8.'
    $udf_string = 'Touchscreen found.'
}
if (Get-PnpDevice | Where-Object { $_.FriendlyName -like '*touch screen*' }) {
    Write-Output 'Touchscreen found from FriendlyName.'
    $udf_string = 'Touchscreen found.'
}
if ($udf_string -eq 'No touchscreen found.') {
    Write-Output $udf_string
}
New-ItemProperty -Path 'HKLM:\Software\CentraStage\' -Name 'Custom20' -Value $udf_string -PropertyType String -Force | Out-Null