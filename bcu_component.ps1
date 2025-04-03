#$env:target_application = 'TeamViewer'
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
Expand-Archive .\bcu-x64.zip -DestinationPath C:\Temp\ -Force -ErrorAction SilentlyContinue
Invoke-Expression "C:\Temp\bcu-x64\BCU-console.exe uninstall $bcul_dir /Q /U /J"
Remove-Item C:\Temp\bcu-x64 -Recurse -Force
Remove-Item $bcul_dir