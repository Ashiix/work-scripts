#$env:target_application = 'Wave'
#$env:target_user = 'TestUser'
$bcul_dir = 'C:\Temp\scriptable.bcul'
$generated_bcul = @'
<?xml version="1.0" encoding="utf-16"?>
<UninstallList xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <Filters>
    <Filter>
      <Name>Component</Name>
      <Exclude>false</Exclude>
      <ComparisonEntries>
        <FilterCondition>
          <InvertResults>false</InvertResults>
          <ComparisonMethod>Any</ComparisonMethod>
          <FilterText>target_application</FilterText>
          <TargetPropertyId />
          <Enabled>true</Enabled>
        </FilterCondition>
      </ComparisonEntries>
      <Enabled>true</Enabled>
    </Filter>
  </Filters>
  <Enabled>true</Enabled>
</UninstallList>
'@.replace('target_application', $env:target_application)
$generated_bcul | Out-File $bcul_dir
Write-Host "Current target: $env:target_application"

$start_info = New-Object System.Diagnostics.ProcessStartInfo
$start_info.FileName = "C:\Temp\bcu-x64\BCU-console.exe"
$start_info.Arguments = "uninstall `"$bcul_dir`" /Q /U /J"
$start_info.UseShellExecute = $false
$start_info.LoadUserProfile = $true
$start_info.UserName = $env:target_user
$start_info.PasswordInClearText = "NotTestUser1!"
$start_info.Domain = $env:COMPUTERNAME

Expand-Archive .\bcu-x64.zip -DestinationPath C:\Temp\ -Force -ErrorAction SilentlyContinue
$bcu_process = [System.Diagnostics.Process]::Start($start_info)
$bcu_process.WaitForExit()
Remove-Item C:\Temp\bcu-x64 -Recurse -Force
Remove-Item $bcul_dir 