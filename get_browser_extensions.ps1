#Requires -Version 5
# PowerShell script for collecting all installed extensions for both Chromium and Firefox-based browsers across all user and browser profiles
# Also has SQLite and Access database integrations, easiest way to connect is to put the DB on a network share

# For once nothing to configure
# Scratch that, where's the database you wanna save to.
$db_path = $env:extension_db_path
# Database to integrate with, comment whole line to disable
$database = "SQLite" # Options: SQLite, Access

# General functions
function retrieve_user_profiles {
    $user_profiles = @()
    Get-ChildItem C:\Users\ | ForEach-Object {
        $user_profiles += $_.FullName
    }
    return $user_profiles
}
function write_to_access_db {
    param (
        $extensions
    )
    try {
        $db_connection = New-Object System.Data.OleDb.OleDbConnection
        $db_connection.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$db_path"
        Write-Host 'Opening connection to Access DB...'
        $db_connection.Open()
        $db_command = New-Object System.Data.OleDb.OleDbCommand
        $db_command.Connection = $db_connection
        foreach ($extension in $extensions) {
            Write-Host "Write to DB: $extension"
            $db_command.CommandText = "INSERT INTO BrowserExtensions (ExtensionName, Endpoint, UserProfile, Browser, ScanDate) VALUES ('$($extension.Name)', '$($extension.Endpoint)', '$($extension.UserProfile)', '$($extension.Browser)', Date())"
            $db_command.ExecuteNonQuery() | Out-Null
        }
        Write-Host 'Done writing entries.'
    }
    catch {
        Write-Error "$_"
    }
    finally {
        $db_connection.Close()
        Write-Host 'Connection to Access DB closed.'
    }
}
function write_to_sqlite_db {
    param (
        $extensions
    )
    Install-Module -Name SQLite
    Import-Module SQLite
    try {
        $db_connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$db_path;")
        Write-Host 'Opening connection to SQLite DB...'
        $db_connection.Open()
        $db_command = $db_connection.CreateCommand()
        foreach ($extension in $extensions) {
            Write-Host "Write to DB: $extension"
            $db_command.CommandText = "INSERT INTO BrowserExtensions (ExtensionName, Endpoint, UserProfile, Browser, ScanDate) VALUES ('$($extension.Name)', '$($extension.Endpoint)', '$($extension.UserProfile)', '$($extension.Browser)', Date())"
            $db_command.ExecuteNonQuery() | Out-Null
        }
        Write-Host 'Done writing entries.'
    }
    catch {
        Write-Error "$_"
    }
    finally {
        $db_connection.Close()
        Write-Host 'Connection to SQLite DB closed.'
    }
}

# Function for handling Google Chrome
function retrieve_chrome_data_dirs {
    param (
        $user_profiles
    )
    $chrome_data_dirs = @()
    $user_profiles | ForEach-Object {
        if (Test-Path $_\AppData\Local\Google\Chrome\) {
            $chrome_data_dirs += "$_\AppData\Local\Google\Chrome\User Data"
        }
    }
    return $chrome_data_dirs
}

# Function for handling Microsoft Edge
function retrieve_edge_data_dirs {
    param (
        $user_profiles
    )
    $edge_data_dirs = @()
    $user_profiles | ForEach-Object {
        if (Test-Path $_\AppData\Local\Microsoft\Edge) {
            $edge_data_dirs += "$_\AppData\Local\Microsoft\Edge\User Data"
        }
    }
    return $edge_data_dirs
}

# Functions for handling various Chromium forks
function retrieve_chromium_profiles {
    param (
        $userdata_dir
    )
    $profiles = @()
    Get-ChildItem $userdata_dir | ForEach-Object {
        if (($_.Name -eq 'Default') -or ($_.Name.Contains('Profile '))) {
            $profiles += $_.FullName
        }
    }
    return $profiles
}
function retrieve_chromium_extensions {
    param (
        $browser_profile_dir
    )
    $extension_ids = @()
    $extensions = @()
    $excluded_names = @('__MSG_extName__', '__MSG_APP_NAME__', '__MSG_fullName__', 'Edge relevant text changes')
    Get-ChildItem $browser_profile_dir\Extensions | ForEach-Object {
        if ($_.Name -ne 'Temp') {
            $extension_ids += $_.FullName
        }
    }
    foreach ($extension_path in $extension_ids) {
        $manifest = $(Get-Content $extension_path\*\manifest.json -Raw | ConvertFrom-Json) 
        foreach ($property in $manifest.PSObject.Properties) {
            if (('short_name' -match $property.Name) -and ($property.Value -notin $excluded_names)) {
                $user_profile = $browser_profile_dir.Substring(0, $($browser_profile_dir.IndexOf('\AppData')))
                $extension = [PSCustomObject]@{
                    Name        = $property.Value
                    Endpoint    = $env:COMPUTERNAME
                    UserProfile = $user_profile
                    Browser     = 'Chromium'
                }
                $extensions += $extension
            }
        }
    }
    return $extensions
}

# Functions for handling Firefox
function retrieve_firefox_extensions {
    param (
        $user_profiles
    )
    $extensions = @()
    $excluded_names = @('Form Autofill', 'Picture-In-Picture', 'Firefox Screenshots', 'WebCompat Reporter', 'Web Compatibility Interventions', 'Add-ons Search Detection', 'Light', 'Dark', 'Firefox Alpenglow', 'Fix add-ons signed before 2018 (Bug 1954818)')
    foreach ($profile in $user_profiles) {
        if (Test-Path $profile\AppData\Roaming\Mozilla\Firefox\Profiles) {
            Get-ChildItem "$profile\AppData\Roaming\Mozilla\Firefox\Profiles\" | ForEach-Object {
                if (Test-Path "$($_.FullName)\extensions.json") {
                    $extensions_data = Get-Content "$($_.FullName)\extensions.json" -Raw | ConvertFrom-Json
                    $extensions_data.addons | ForEach-Object {
                        if ($_.defaultLocale.name -and ($_.defaultLocale.name -notin $excluded_names) -and ($_.defaultLocale.name -notlike 'System theme*')) {
                            $extension = [PSCustomObject]@{
                                Name        = $_.defaultLocale.name
                                Endpoint    = $env:COMPUTERNAME
                                UserProfile = $profile
                                Browser     = 'Firefox'
                            }
                            $extensions += $extension
                        }
                    }
                }
            }
        }
    }
    return $extensions
}

# Main function
function get_browser_extensions {
    $extensions = @()

    # Handle Google Chrome
    $chrome_profiles = @()
    retrieve_chrome_data_dirs $(retrieve_user_profiles) | ForEach-Object {
        $chrome_profiles += retrieve_chromium_profiles $_
    }
    $chrome_profiles | ForEach-Object {
        retrieve_chromium_extensions $_ | ForEach-Object {
            $_.Browser = 'Chrome'
            if ($_ -notin $extensions) {
                $extensions += $_
            }
        }
    }

    # Handle Microsoft Edge 
    $edge_profiles = @()
    retrieve_edge_data_dirs $(retrieve_user_profiles) | ForEach-Object {
        $edge_profiles += retrieve_chromium_profiles $_
    }
    $edge_profiles | ForEach-Object {
        retrieve_chromium_extensions $_ | ForEach-Object {
            $_.Browser = 'Edge'
            if ($_ -notin $extensions) {
                $extensions += $_
            }
        }
    }

    # Handle Firefox
    retrieve_firefox_extensions $(retrieve_user_profiles) | ForEach-Object {
        if ($_ -notin $extensions) {
            $extensions += $_
        }
    }
    
    # Return all retrieved extensions across all browsers and profiles
    return $extensions
}

$extensions = $(get_browser_extensions)

if ($database -eq 'SQLite') {
    write_to_sqlite_db $extensions
}
elseif ($database -eq 'Access') {
    write_to_access_db $extensions
}