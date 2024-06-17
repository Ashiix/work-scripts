# Powershell script that monitors disk usage over extended periods of time, and... 
# TODO: monitor usage reports and report spikes of usage
# User must have access to the CentraStage registry key to save to a UDF, if run as a component it will be run as an administrator that does
# Computer\HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage

# Set script's data path, obscured for privacy
$data_path = "$env:script_data_path\Disk\usage_history.json"
# UDF to save to
$udf = "Custom18"

#Initialize variables
$prev_percent_used = [Ordered]@{}
$drives_iterated = ''
$percent_used = [Ordered]@{}
$usage_history = [Ordered]@{}
Set-Item env:used_drives -Value('')
$percent_used_string = ""

# Create directory for script data if it doesn't exist
if (!(Test-Path $data_path)) {
    "Data directory not found, creating now."
    mkdir "$env:script_data_path\Disk"
    New-Item $data_path
}

# Fetch usage data from Win32_LogicalDisk and filter out excess data
$usage_table = (Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID, @{'Name' = 'Size'; Expression = { [int]($_.Size / 1GB) }}, @{'Name' = 'Free'; Expression = { [int]($_.FreeSpace / 1GB) }}) | Out-String
# Remove trailing : from the drive identifier to make values easier to work with
$usage_table = ($usage_table -replace ‘[:]' -replace '[-]').Trim()
# Get number of drives in machine by taking the table and split based on carriage returns
$table_elements = ($usage_table -split '\n').Length
# Iterate through table objects and create a odict
for ($line = 2; $line -lt $table_elements; $line++) {
    # Get drive indicator
    $iterated_drive = ((($usage_table -split '\n')[$line]).Substring(0,1))
    $drives_iterated += "$iterated_drive "
    # Use regex to remove excess spaces betwen elements to allow splitting based on whitespace, and fetch drive usage from clean string
    $iterated_drive_usage = [regex]::Replace((($usage_table -split '\n')[$line].Substring(9).Trim()), '\s+', ' ')
    # Calculate a whole number percentage for used drive
    $percent_used += @{$iterated_drive = ([int]((([int]$iterated_drive_usage.Split(' ')[0] - [int]$iterated_drive_usage.Split(' ')[1]) / [int]$iterated_drive_usage.Split(' ')[0]) * 100))}
}
# Remove trailing space from iterated list
$drives_iterated = $drives_iterated.Trim()
# Iterate through each object in odict and check if the usage has a 30% or higher spike, if so send an error that will be recognized by Datto
$prev_percent_used.GetEnumerator() | ForEach-Object {
    if ($percent_used[$_.Key]*1.30 -le $_.Value) {
        "Extreme usage spike detected on {0} drive!" -f $_.Key
    }
}
# Create a string with the percentage used to store in the $usage_history odict
$percent_used.GetEnumerator() | ForEach-Object {
    $percent_used_string +=  $_.Key + ":" + $_.Value + " | "
}
# Retrieve the history json and store as odict
$history_json = (Get-Content $data_path | ConvertFrom-Json)
($history_json).psobject.properties | ForEach-Object { $usage_history[$_.Name] = $_.Value }
# Retrieve and store UNIX timestamp
$present_date_present_time = [int](Get-Date -UFormat %s -Millisecond 0)
# Add the newly acquired data to the history odict
$usage_history += @{[String]$present_date_present_time = $percent_used_string}
# Save the full history odict to disk in json for use on next execution
$usage_history | ConvertTo-Json | Out-File $data_path

# Add current usage data to UDF
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $udf /t REG_SZ /d "$percent_used_string" /f

