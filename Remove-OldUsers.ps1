#Requires -Version 5

# A PowerShell script that can be run on a schedule to clean up old user profiles

# CONFIG

# How login history is determined:
$history_method = 'lastloadtime' # Options are "lastloadtime", "ntuser.dat", "lastlogintime"

# ^ CONFIG

if ($history_method -eq 'lastloadtime') {
    $standard_users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }
    
    $standard_users | ForEach-Object {
        $reg_key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($_.SID)"
        $reg_values = Get-ItemProperty -Path $reg_key -ErrorAction SilentlyContinue
        $load_time = [DateTime]::FromFileTime("0x$($reg_values.LocalProfileLoadTimeHigh.ToString('X8'))$($reg_values.LocalProfileLoadTimeLow.ToString('X8'))")
        $days_since = ([DateTime]::Now - $load_time).Days
        $directory_size = $([Math]::Round((Get-ChildItem $_.LocalPath -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1GB, 2))
        Write-Output $_.LocalPath.Split('\')[-1]
        Write-Output "$load_time"
        Write-Output "$directory_size GB"
        Write-Output "$days_since days since last used."
        Write-Output ''
    }
}

elseif ($history_method -eq 'ntuser.dat') {
    Write-Output 'Using ntuser.dat method...'
    $standard_users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }
    $removal_targets = @()
    foreach ($user in $standard_users) {
        $last_modified = [System.IO.Directory]::GetLastWriteTime("$($user.LocalPath)/ntuser.dat")
        $directory_size = $([Math]::Round((Get-ChildItem $user.LocalPath -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1GB, 2))
        $days_since = ([DateTime]::Now - $last_modified).Days
        Write-Output $user.LocalPath.Split('\')[-1]
        Write-Output $last_modified
        Write-Output "$directory_size GB"
        Write-Output "$days_since days since last used."
        Write-Output ''
        if ($directory_size -ge 5.00) {
            $removal_targets += $user
        }
    }
}
elseif ($history_method -eq 'lastlogintime') {
    Write-Output 'Using lastlogintime method...'
    $standard_users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }
    $standard_users | ForEach-Object {
        $directory_size = $([Math]::Round((Get-ChildItem $_.LocalPath -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1GB, 2))
        $days_since = ([DateTime]::Now - $_.LastUseTime).Days
        Write-Output $_.LocalPath.Split('\')[-1]
        Write-Output $_.LastUseTime
        Write-Output "$directory_size GB"
        Write-Output "$days_since days since last used."
        Write-Output ''
    }
}