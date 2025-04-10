#Requires -Version 5

# Relies on Office Deployment tool
# Version numbers/information can be found here: https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date

#[String]$target_version = "16.0.$env:target_build"

#[String]$data_path = 'C:\Temp\m365'
# [String]$source_path = "$data_path\install"
# [String]$download_config_path = 'C:\Temp\m365_download.xml'
# [String]$download_config_template = @'
# <Configuration> 
#     <Add SourcePath="source_path" OfficeClientEdition="target_arch" Version="target_version"> 
#         <Product ID="product_id" > 
#             <Language ID="language_id" />      
#         </Product> 
#     </Add> 
# </Configuration>
# '@
# # Replacements: source_path, target_arch, target_version, product_id, language_id


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
  <Updates Enabled="FALSE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

# Replacements: target_arch, target_channel, target_build, product_id


# function m365_download {
#     param (
#         $ParameterName
#     )
# }

[UInt16]$target_arch = '64'
[String]$target_channel = 'Current'
[String]$target_build = '18623.20178'
[String]$product_id = 'O365ProPlusRetail' # (https://learn.microsoft.com/en-us/microsoft-365/troubleshoot/installation/product-ids-supported-office-deployment-click-to-run)

function m365_install {
    param (
        [String]$install_config_template,
        [UInt16]$target_arch,
        [String]$target_channel,
        [String]$target_build,
        [String]$product_id
    )
    [String]$install_config = $install_config_template
    $replacements = @{ 'target_arch' = "$target_arch"; 'target_channel' = "$target_channel"; 'target_build' = "$target_build"; 'product_id' = "$product_id" } 
    $replacements.Keys | ForEach-Object {
        $install_config = $install_config -replace $_, $replacements[$_]
    }
    $install_config | Out-File -FilePath $install_config_path -Force
    .\odt.exe /configure $install_config_path
}

m365_install $install_config_template $target_arch $target_channel $target_build $product_id 
