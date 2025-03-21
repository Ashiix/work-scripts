function retrieve_user_profiles {
    $user_profiles = @()
    Get-ChildItem C:\Users\ | ForEach-Object {
        $user_profiles += $_.FullName
    }
    return $user_profiles
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
    $extension_names = @()
    $excluded_names = @('__MSG_extName__', '__MSG_APP_NAME__', '__MSG_fullName__')
    Get-ChildItem $browser_profile_dir\Extensions | ForEach-Object {
        if ($_.Name -ne 'Temp') {
            $extension_ids += $_.FullName
        }
    }
    foreach ($extension_path in $extension_ids) {
        $manifest = $(Get-Content $extension_path\*\manifest.json -Raw | ConvertFrom-Json) 
        foreach ($property in $manifest.PSObject.Properties) {
            if (('short_name' -match $property.Name) -and ($property.Value -notin $excluded_names)) {
                $extension_names += $property.Value
            }
        }
    }
    return $extension_names
}


# Functions for handling Firefox
function retrieve_firefox_extensions {
    param (
        $user_profile
    )
    return ''
}

function get_browser_extensions {
    $all_extensions = @()

    # Handle Google Chrome
    $chrome_profiles = @()
    retrieve_chrome_data_dirs $(retrieve_user_profiles) | ForEach-Object {
        $chrome_profiles += retrieve_chromium_profiles $_
    }
    $chrome_profiles | ForEach-Object {
        retrieve_chromium_extensions $_ | ForEach-Object {
            if ($_ -notin $all_extensions) {
                $all_extensions += $_
            }
        }
    }

    # Return all retrieved extensions across all browsers and profiles
    return $all_extensions
}

get_browser_extensions