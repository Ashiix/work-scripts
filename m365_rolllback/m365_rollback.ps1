#Requires -Version 5

# Relies on Office Deployment tool
# Version numbers/information can be found here: https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date

# CONFIG 
[UInt16]$target_arch = '64'
[String]$target_channel = 'Current'
[String]$target_build = '' # https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date
[String]$product_id = 'O365ProPlusRetail' # https://learn.microsoft.com/en-us/microsoft-365/troubleshoot/installation/product-ids-supported-office-deployment-click-to-run
[System.Boolean]$enable_updates = $false
# ^ CONFIG ^

# DRMM HANDLING
# $target_arch = $env:architecture
# $target_channel = $env:release_channel
# $target_build = $env:build
# $product_id = $env:product_id
# $enable_updates = $env:enable_updates

[String]$install_config_path = 'C:\Temp\m365_install.xml'
[String]$install_config_template = @'
<Configuration>
  <Add OfficeClientEdition="target_arch" Channel="target_channel" Version="16.0.target_build" MigrateArch="TRUE">
    <Product ID="product_id">
      <Language ID="en-us" />
      <Language ID="MatchPreviousMSI" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="Bing" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

function m365_install {
    param (
        [String]$install_config_template,
        [UInt16]$target_arch,
        [String]$target_channel,
        [String]$target_build,
        [String]$product_id,
        [System.Boolean]$enable_updates
    )
    [String]$install_config = $install_config_template
    [System.Collections.Hashtable]$replacements = @{ 'target_arch' = "$target_arch"; 'target_channel' = "$target_channel"; 'target_build' = "$target_build"; 'product_id' = "$product_id" } 
    $replacements.Keys | ForEach-Object {
        $install_config = $install_config -replace $_, $replacements[$_]
    }
    if ($target_build -eq 'Latest' -or $target_build -eq '') {
        $install_config = $install_config -replace 'Version="16.0.Latest" ', ''
        $install_config = $install_config -replace 'Version="16.0." ', ''
    }
    if (-not $enable_updates) {
        $install_config = $install_config -replace 'Updates Enabled=""', 'Updates Enabled="FALSE"'
    } else {
        $install_config = $install_config -replace 'Updates Enabled=""', 'Updates Enabled="TRUE"'
    }
    
    $install_config | Out-File -FilePath $install_config_path -Force
    Write-Output $install_config
    .\odt.exe /configure $install_config_path
}

m365_install $install_config_template $target_arch $target_channel $target_build $product_id $enable_updates
