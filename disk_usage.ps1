# Powershell script that monitors disk usage over extended periods of time and saves the percentage change in a Datto UDF

# User must have access to the CentraStage registry key to save to a UDF, if run as a component it will be run as an administrator that does
# Computer\HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage


# CONFIG
# Set script's data path, obscured for privacy; must either have the data path ($env:script_data_path) be set in Datto,
# or be changed to include full path
$data_path = "$env:script_data_path\Disk\usage_history.json"
# UDF to save data to; must be changed to target UDF
$udf = "Custom18"
# Method of reporting spikes
# Valid methods are File, Registry
$alert_method = "Registry"
# Path to registy key for sending alerts to; must be in path, set in Datto, or changed below
$reg_key_location = $env:disk_alert_key
# ^ CONFIG ^


# Function to calculate usage history
function usage_history {
    # Set parameters
    param (
        $time_difference, 
        $number_entries,
        $sorted_usage_history, 
        $percent_used, 
        $percent_used_string
    )
    # In try/catch for error handling in case of invalid time dif criteria
    try {
        # Create new change var in current scope
        $change = [Ordered]@{}
        # Verify that the number of entries in the history json is enough to calculate data
        if ($sorted_usage_history.Count -ge $number_entries) {
            # Find most recent usage that is older than $time_difference
            foreach ($pair in $sorted_usage_history.GetEnumerator()) {
                if ($sorted_usage_history.Keys[0] - $time_difference -ge $pair.Key) {
                    $used_string = $pair.Value
                    break
                }
            }
            # Convert usage string to ordered list
            $prev_used = $used_string.replace(' ', '').split('|')
            for ($i = 0; $i -lt $percent_used.Count; $i++) {
                # Get previous usage
                $iterated_old_usage = $prev_used[$i].split(':')[1]
                # Get current usage
                $iterated_current_usage = $percent_used_string.replace(' ', '').split('|')[$i].split(':')[1]
                $change += @{$prev_used[$i].split(':')[0] = [int]((($iterated_current_usage - $iterated_old_usage) / $iterated_old_usage) * 100) }
            }
            # Return generated change data
            return $change
        }
        else {
            Write-Host "Not enough entries to calculate usage."
        }
    }
    catch {
        Write-Host "No entries that match time difference criteria."
    }
}

function generate_staging_udf {
    # Set parameters
    param (
        $change,
        $name
    )
    # Add data if it exists
    if ($change.Keys -gt 0) {
        $staged_udf = "$name - "
        foreach ($pair in $change.GetEnumerator()) {
            $pair_drive = $pair.Name
            $pair_change = $pair.Value
            $staged_udf += "${pair_drive}:$pair_change%, "
        }
        return $staged_udf.Substring(0, $staged_udf.Length - 2)
    }
}

# Generate an alert file with a unique name
function alert_file {
    param (
        $present_date_present_time
    )
    New-Item -Path $data_path\.. -Name "alert_$present_date_present_time" -ItemType File
}

function alert_regkey {
    param (
        $present_date_present_time
    )
    try { New-Item "$reg_key_location" -ErrorAction Stop }
    catch { Write-Host "Key already exists, skipping creation." }
    REG ADD $reg_key_location /v "Disk_Alert" /t REG_SZ /d "$present_date_present_time" /f
}

function generate_alert_string {
    param (
        $drives
    )
    "Usage spike detected on $drives"
}

# Wrap in function to prevent a partially downloaded/corrupted script from running
function disk_usage {
    #Initialize variables
    $drives_iterated = ''
    $percent_used = [Ordered]@{}
    $usage_history = [Ordered]@{}
    $sorted_usage_history = [Ordered]@{}
    Set-Item env:used_drives -Value('')
    $percent_used_string = ""
    $udf_string = ""
    $alert_drives = ""

    # Create directory for script data if it doesn't exist
    if (!(Test-Path $data_path)) {
        "Data directory not found, creating now."
        mkdir "$env:script_data_path\Disk"
        New-Item $data_path
    }

    # Fetch usage data from Win32_LogicalDisk and filter out excess data
    $usage_table = (Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID, @{'Name' = 'Size'; Expression = { [int]($_.Size / 1GB) } }, @{'Name' = 'Free'; Expression = { [int]($_.FreeSpace / 1GB) } }) | Out-String
    # Remove trailing : from the drive identifier to make values easier to work with
    $usage_table = ($usage_table -replace ‘[:]' -replace '[-]').Trim()
    # Get number of drives in machine by taking the table and split based on carriage returns
    $table_elements = ($usage_table -split '\n').Length
    # Iterate through table objects and create a odict
    for ($line = 2; $line -lt $table_elements; $line++) {
        # Get drive indicator
        $iterated_drive = ((($usage_table -split '\n')[$line]).Substring(0, 1))
        $drives_iterated += "$iterated_drive "
        # Use regex to remove excess spaces betwen elements to allow splitting based on whitespace, and fetch drive usage from clean string
        $iterated_drive_usage = [regex]::Replace((($usage_table -split '\n')[$line].Substring(9).Trim()), '\s+', ' ')
        # Calculate a whole number percentage for used drive
        $percent_used += @{$iterated_drive = ([int]((([int]$iterated_drive_usage.Split(' ')[0] - [int]$iterated_drive_usage.Split(' ')[1]) / [int]$iterated_drive_usage.Split(' ')[0]) * 100)) }
    }
    # Remove trailing space from iterated list
    $drives_iterated = $drives_iterated.Trim()

    # Create a string with the percentage used to store in the $usage_history odict
    $percent_used.GetEnumerator() | ForEach-Object {
        $percent_used_string += $_.Key + ":" + $_.Value + " | "
    }
    # Retrieve the history json and store as odict
    $history_json = (Get-Content $data_path | ConvertFrom-Json)
    ($history_json).psobject.properties | ForEach-Object { $usage_history[$_.Name] = $_.Value }
    # Retrieve and store UNIX timestamp
    $present_date_present_time = [int](Get-Date -UFormat %s -Millisecond 0)
    # Add the newly acquired data to the history odict
    $usage_history += @{[String]$present_date_present_time = $percent_used_string }
    # Save the full history odict to disk in json for use on next execution
    $usage_history | ConvertTo-Json | Out-File $data_path

    # Iterate through previously saved usage data, save daily/weekly/monthly percent increase/decrease to UDF for each drive, 
    # output information to StdOut for recordkeeping
    $usage_history.GetEnumerator() | Sort-Object -Descending -Property Key | ForEach-Object {
        $sorted_usage_history += @{$_.Key = $_.Value }
    }

    # Using the most recent timestamp value, iterate through timestamps until it finds one that is one day/week/month older
    $daily_change = usage_history 86400 3 $sorted_usage_history $percent_used $percent_used_string 
    $weekly_change = usage_history 604800 4 $sorted_usage_history $percent_used $percent_used_string 
    $monthly_change = usage_history 2629746 5 $sorted_usage_history $percent_used $percent_used_string
    $yearly_change = usage_history 31556952 6 $sorted_usage_history $percent_used $percent_used_string

    # Create UDF string
    $udf_string += $(generate_staging_udf $daily_change "Daily")
    $udf_string += $(generate_staging_udf $weekly_change " | Weekly")
    $udf_string += $(generate_staging_udf $monthly_change " | Monthly")
    $udf_string += $(generate_staging_udf $yearly_change " | Yearly")
    # Write data to console
    Write-Output $udf_string
    # Add history data to UDF
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $udf /t REG_SZ /d "$udf_string" /f

    # Create alert if there is any daily drive change over 30%
    $daily_change.GetEnumerator() | ForEach-Object {
        $alert_drives += $_.Key
        if ([Math]::Abs([int]$_.Value) -ge 30) {
            $alert_drives += $_.Key
            if ($alert_method -eq "File") {
                alert_file $present_date_present_time
            }
            elseif ($alert_method -eq "Registry") {
                alert_regkey $present_date_present_time
            }
        }
    }
}
disk_usage
