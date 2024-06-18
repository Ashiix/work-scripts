# Powershell script that monitors disk usage over extended periods of time, save values to UDF, and... 
# TODO: monitor usage reports and report spikes of usage

# User must have access to the CentraStage registry key to save to a UDF, if run as a component it will be run as an administrator that does
# Computer\HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage

# Wrap in function to prevent a partially downloaded/corrupted script from running
function Main {
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
$daily_name = ""
$weekly_name = ""
$monthly_name = ""

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



# REMOVE COMMENT VVVVV

#$usage_history | ConvertTo-Json | Out-File $data_path

# Add current usage data to UDF
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $udf /t REG_SZ /d "$percent_used_string" /f

# Iterate through previously saved usage data, save daily/weekly/monthly percent increase/decrease to UDF for each drive, 
# output information to StdOut for recordkeeping
#$usage_history
$reversed_usage_history = $usage_history.GetEnumerator() | Sort-Object -Descending Name

# Using the most recent timestamp value, iterate through timestamps until it finds one that is one day/week/month older
#$usage_history.getEnumerator() | ForEach-Object { }
# If there are 2 and the first and last are over 24 hours apart (86400), calculate daily percentage change
if ($usage_history.Count -ge 2) {
    foreach ($pair in $reversed_usage_history) {
        if ($reversed_usage_history[0].Name-8400 -ge $pair.Name) {
            $daily_name = $pair.Name
            break
        }
    }
    $daily_name
} else {
    Write-Output "Not enough entries to calculate daily."
}

# If there are 3 and the first and last are over one week apart (604800), calculate weekly percentage change
if ($usage_history.Count -ge 3) {
    foreach ($pair in $reversed_usage_history) {
        if ($reversed_usage_history[0].Name-604800 -ge $pair.Name) {
            $weekly_name = $pair.Name
            break
        }
    }
    $weekly_name
} else {
    Write-Output "Not enough entries to calculate weekly."
}
# If there are 4 and the first and last are over one month apart (2592000), calculate monthly percentage change
if ($usage_history.Count -ge 4) {
    foreach ($pair in $reversed_usage_history) {
        if ($reversed_usage_history[0].Name-2592000 -ge $pair.Name) {
            $monthly_name = $pair.Name
            break
        }
    }
    $monthly_name
} else {
    Write-Output "Not enough entries to calculate monthly."
}



# Save data in the format:    Daily - DRIVE:CHANGE%, DRIVE:CHANGE% | Weekly - DRIVE:CHANGE%, DRIVE:CHANGE% | Monthly - DRIVE:CHANGE%, DRIVE:CHANGE%
}
Main
