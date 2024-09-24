# Powershell script that monitors disk usage over extended periods of time and saves the percentage change in a Datto UDF

# User must have access to the CentraStage registry key to save to a UDF, if run as a component it will be run as an administrator that does
# Computer\HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage


# CONFIG
# Set script's data path, obscured for privacy; must either have the data path ($env:script_data_path) be set in Datto,
# or be changed to include full path
$data_path = "$env:script_data_path\Disk\usage_history.json"
# UDF to save data to; must be changed to target UDF
$udf = "Custom18"
# ^ CONFIG ^


# Wrap in function to prevent a partially downloaded/corrupted script from running
function disk_usage {
#Initialize variables
$drives_iterated = ''
$percent_used = [Ordered]@{}
$usage_history = [Ordered]@{}
Set-Item env:used_drives -Value('')
$percent_used_string = ""
$daily_change = [Ordered]@{}
$weekly_change = [Ordered]@{}
$monthly_change = [Ordered]@{}
$udf_string = ""

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

# Iterate through previously saved usage data, save daily/weekly/monthly percent increase/decrease to UDF for each drive, 
# output information to StdOut for recordkeeping
$reversed_usage_history = $usage_history.GetEnumerator() | Sort-Object -Descending Name

# Using the most recent timestamp value, iterate through timestamps until it finds one that is one day/week/month older
# If there are 2 and the first and last are over 24 hours apart (86400), calculate daily percentage change
if ($usage_history.Count -ge 3) {
    foreach ($pair in $reversed_usage_history) {
        # Find most recent usage that is older than one day
        if ($reversed_usage_history[0].Name-86400 -ge $pair.Name) {
            $daily_used_string = $pair.Value
            break
        }
    }
    $daily_prev_used = $daily_used_string.replace(' ', '').split('|')
    for ($i = 0; $i -lt $percent_used.Count; $i++) {
        # Get previous usage
        $iterated_old_usage = $daily_prev_used[$i].split(':')[1]
        # Get current usage
        $iterated_current_usage = $percent_used_string.replace(' ', '').split('|')[$i].split(':')[1]
        $daily_change += @{$daily_prev_used[$i].split(':')[0] = [int]((($iterated_current_usage - $iterated_old_usage) / $iterated_old_usage) * 100)}
    }
} else {
    Write-Output "Not enough entries to calculate daily."
}

# If there are 3 and the first and last are over one week apart (604800), calculate weekly percentage change
if ($usage_history.Count -ge 4) {
    foreach ($pair in $reversed_usage_history) {
        # Find most recent usage that is older than one week
        if ($reversed_usage_history[0].Name-604800 -ge $pair.Name) {
            $weekly_used_string = $pair.Value
            break
        }
    }
    $weekly_prev_used = $weekly_used_string.replace(' ', '').split('|')
    for ($i = 0; $i -lt $percent_used.Count; $i++) {
        # Get previous usage
        $iterated_old_usage = $weekly_prev_used[$i].split(':')[1]
        # Get current usage
        $iterated_current_usage = $percent_used_string.replace(' ', '').split('|')[$i].split(':')[1]
        $weekly_change += @{$weekly_prev_used[$i].split(':')[0] = [int]((($iterated_current_usage - $iterated_old_usage) / $iterated_old_usage) * 100)}
    }
} else {
    Write-Output "Not enough entries to calculate weekly."
}
# If there are 4 and the first and last are over one month apart (2592000), calculate monthly percentage change
if ($usage_history.Count -ge 5) {
    foreach ($pair in $reversed_usage_history) {
        # Find most recent usage that is older than one month
        if ($reversed_usage_history[0].Name-2592000 -ge $pair.Name) {
            $monthly_used_string = $pair.Value
            break
        }
    }
    $monthly_prev_used = $monthly_used_string.replace(' ', '').split('|')
    for ($i = 0; $i -lt $percent_used.Count; $i++) {
        # Get previous usage
        $iterated_old_usage = $monthly_prev_used[$i].split(':')[1]
        # Get current usage
        $iterated_current_usage = $percent_used_string.replace(' ', '').split('|')[$i].split(':')[1]
        $monthly_change += @{$monthly_prev_used[$i].split(':')[0] = [int]((($iterated_current_usage - $iterated_old_usage) / $iterated_old_usage) * 100)}
    }
} else {
    Write-Output "Not enough entries to calculate monthly."
}

# Add daily data if it exists
if ($daily_change.Keys -gt 0) {
    $udf_string = "Daily - "
    foreach ($pair in $daily_change.GetEnumerator()) {
        $pair_drive = $pair.Name
        $pair_change = $pair.Value
        $udf_string += "${pair_drive}:$pair_change%, "
    }
    $udf_string = $udf_string.Substring(0, $udf_string.Length-2)
}
# Add weekly data if it exists
if ($weekly_change.Keys -gt 0) {
    $udf_string += " | Weekly - "
    foreach ($pair in $weekly_change.GetEnumerator()) {
        $pair_drive = $pair.Name
        $pair_change = $pair.Value
        $udf_string += "${pair_drive}:$pair_change%, "
    }
    $udf_string = $udf_string.Substring(0, $udf_string.Length-2)
}
# Add monthly data if it exists
if ($monthly_change.Keys -gt 0) {
    $udf_string += " | Monthly - "
    foreach ($pair in $monthly_change.GetEnumerator()) {
        $pair_drive = $pair.Name
        $pair_change = $pair.Value
        $udf_string += "${pair_drive}:$pair_change%, "
    }
    $udf_string = $udf_string.Substring(0, $udf_string.Length-2)
}

# Write data to console
Write-Output $udf_string
# Add history data to UDF
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $udf /t REG_SZ /d "$udf_string" /f
}
disk_usage
