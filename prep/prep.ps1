# PowerShell script for prepping work machines

function Prep {
    $data_path = "$env:script_data_path\Prep"
    if (!(Test-Path $data_path)) {
        Write-Host "Data directory not found, creating now."
        New-Item $data_path -Type Directory
    }   
}

Prep