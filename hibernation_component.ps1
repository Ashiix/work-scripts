#Requires -Version 5

# Script designed to be run once when a device is low on storage
# Will disable hibernation and register a task to check storage, if above a certain threshold it will be reenabled.

$env:reenable_hibernation = $true
$env:reenable_threshold = 20 # In Gigabytes

function hibernation_component {
    powercfg.exe -h off
    if ($env:reenable_hibernation) {
        $job_options = New-ScheduledJobOption -RunElevated -WakeToRun
        $job_trigger = New-JobTrigger -Daily -At '2:30 PM'
        Register-ScheduledJob -Name 'Reenable-Hibernation' -ScheduledJobOption $job_options -Trigger $job_trigger -ScriptBlock {
            $total_memory = 0
            Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object Capacity | ForEach-Object {
                $total_memory += ($_.Capacity / 1GB)
            }
            $projected_hiberfil_size = ($total_memory * 0.4)
            $usage_table = (Get-WmiObject -Class Win32_LogicalDisk | 
                Select-Object -Property DeviceID, @{'Name' = 'Size'; Expression = { [int]($_.Size / 1GB) } }, 
                @{'Name' = 'Free'; Expression = { [int]($_.FreeSpace / 1GB) } })
            $usage_table | ForEach-Object {
                if ($_.DeviceID -eq 'C:') {
                    $c_free = $_.Free
                    Write-Output "Found C drive, free space remaining is: $c_free"
                }
            }
            if ($c_free -ge ($projected_hiberfil_size + 20)) {
                Write-Output 'Hibernation re-enable threshold reached.'
                powercfg.exe -h on
                Write-Output 'Re-enabled.'
                Write-Output 'Removing scheduled job.'
                Unregister-ScheduledJob -Name 'Reenable-Hibernation'
            }
            else {
                Write-Output 'Hibernation re-enable threshold NOT met. '
            }
        }
        $task_principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        Set-ScheduledTask -TaskPath '\Microsoft\Windows\PowerShell\ScheduledJobs' -TaskName 'Reenable-Hibernation' -Principal $task_principal
    }
}

hibernation_component