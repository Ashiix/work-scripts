Get-CimInstance -Class CIM_PointingDevice | ForEach-Object {
    Write-Host $_.PointingType
    if ($_.PointingType -eq 8) {
        Write-Output 'Touchscreen found, updating UDF.'
        New-ItemProperty -Path 'HKLM:\Software\CentraStage\' -Name 'Custom20' -Value 'Touchscreen present.' -PropertyType String -Force | Out-Null
        return
    }
    else {
        Write-Output 'No PointingDevice type 8 (Touchscreen) found.'
        New-ItemProperty -Path 'HKLM:\Software\CentraStage\' -Name 'Custom20' -Value 'No touchscreen found.' -PropertyType String -Force | Out-Null
    }
}
if (Get-PnpDevice | Where-Object { $_.FriendlyName -like '*touch screen*' }) {
    New-ItemProperty -Path 'HKLM:\Software\CentraStage\' -Name 'Custom20' -Value 'Touchscreen present.' -PropertyType String -Force | Out-Null
}