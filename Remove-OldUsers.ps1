#Requires -Version 5

# A PowerShell script that can be run on a schedule to clean up old user profiles

# CONFIG
# How login history is determined: 
$history_method = 'lastloadtime' # Default is "lastloadtime", other options are "ntuser.dat", "lastlogintime"
# Minimum days required for profile removal (inclusive), default is 90
$remove_older_than = 90
#$ignore_users = @("Scanner", "Treysta")
# ^ CONFIG

function Get-LocalLoadTime {
    param (
        $reg_values
    )
    return [DateTime]::FromFileTime("0x$($reg_values.LocalProfileLoadTimeHigh.ToString('X8'))$($reg_values.LocalProfileLoadTimeLow.ToString('X8'))")
}   

function Get-LoadTime {
    param (
        $reg_values
    )
    return [DateTime]::FromFileTime("0x$($reg_values.ProfileLoadTimeHigh.ToString('X8'))$($reg_values.ProfileLoadTimeLow.ToString('X8'))")
}

function Remove-OldUsers {
    param (
        $history_method,
        $remove_older_than
    )
    if ($history_method -eq 'lastloadtime') {
        $standard_users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_ }
            $to_remove = $()
        $standard_users | ForEach-Object {
            $reg_key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($_.SID)"
            $reg_values = Get-ItemProperty -Path $reg_key -ErrorAction SilentlyContinue
            $load_time = 0
            try {
                Write-Output 'Attempting local profile load time.'
                $load_time = Get-LocalLoadTime($reg_values)
                Write-Output 'Using local profile load time.'
            }
            catch {
                try {
                    Write-Output 'Failed...'
                    Write-Output 'Attempting profile load time.'
                    $load_time = Get-LoadTime($reg_values)
                    Write-Output 'Using profile load time.'
                }
                catch {
                    Write-Host "Failed, skipping user.`n"
                    $load_time = 0
                }
            }
            if (-not $load_time -eq 0) {
                $days_since = ([DateTime]::Now - $load_time).Days
                $directory_size = $([Math]::Round((Get-ChildItem $_.LocalPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB, 2))
                Write-Output $_.LocalPath.Split('\')[-1]
                Write-Output "$load_time"
                Write-Output "$directory_size GB"
                Write-Output "$days_since days since last used."
                Write-Output ''
                if ($days_since -ge $remove_older_than) {
                    $to_remove += @($_)
                }
            }
        }
    }
    if ($to_remove) {
        Write-Output "Removing users older than $remove_older_than days..."
        $to_remove | ForEach-Object {
            if ($_.SID) {
                #$reg_key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($_.SID)"
                Write-Output $_.LocalPath.Split('\')[-1]
                #Remove-Item $reg_key -Force
                #Remove-Item $_.LocalPath -Recurse -Force
                #Remove-Item $_.LocalPath -Recurse -Force
                Remove-CimInstance -WhatIf $_
            }
        }
    }
    else {
        Write-Output 'No users fit deletion criteria.'
    }
}

Remove-OldUsers $history_method $remove_older_than

# elseif ($history_method -eq 'ntuser.dat') {
#     Write-Output 'Using ntuser.dat method...'
#     $standard_users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }
#     $removal_targets = @()
#     foreach ($user in $standard_users) {
#         $last_modified = [System.IO.Directory]::GetLastWriteTime("$($user.LocalPath)/ntuser.dat")
#         $directory_size = $([Math]::Round((Get-ChildItem $user.LocalPath -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1GB, 2))
#         $days_since = ([DateTime]::Now - $last_modified).Days
#         Write-Output $user.LocalPath.Split('\')[-1]
#         Write-Output $last_modified
#         Write-Output "$directory_size GB"
#         Write-Output "$days_since days since last used."
#         Write-Output ''
#         if ($directory_size -ge 5.00) {
#             $removal_targets += $user
#         }
#     }
# }
# elseif ($history_method -eq 'lastlogintime') {
#     Write-Output 'Using lastlogintime method...'
#     $standard_users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }
#     $standard_users | ForEach-Object {
#         $directory_size = $([Math]::Round((Get-ChildItem $_.LocalPath -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1GB, 2))
#         $days_since = ([DateTime]::Now - $_.LastUseTime).Days
#         Write-Output $_.LocalPath.Split('\')[-1]
#         Write-Output $_.LastUseTime
#         Write-Output "$directory_size GB"
#         Write-Output "$days_since days since last used."
#         Write-Output ''
#     }
# }