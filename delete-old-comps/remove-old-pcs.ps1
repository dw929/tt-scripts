Import-Module ActiveDirectory

# Settings
$DaysInactive = 365
$Time = (Get-Date).AddDays(-$DaysInactive)
$ExportPath = "C:\Temp\InactiveComputers_$(Get-Date -Format yyyy-MM-dd).csv"

# Get inactive computers
$Computers = Get-ADComputer -Filter {LastLogonDate -lt $Time -and Enabled -eq $true} `
    -Properties LastLogonDate, Description, OperatingSystem, DistinguishedName

# Export first (safety step)
$Computers |
Select-Object Name, LastLogonDate, Description, OperatingSystem, DistinguishedName |
Sort-Object LastLogonDate |
Export-Csv $ExportPath -NoTypeInformation

Write-Host "Export completed:" $ExportPath
Write-Host "Starting updates and disable process..."

foreach ($Computer in $Computers) {

    if ($Computer.LastLogonDate) {

        # Format date
        $LastLogonFormatted = $Computer.LastLogonDate.ToString("yyyy-MM-dd")

        # Remove previous LastLogon entry if exists
        $NewDescription = $Computer.Description -replace "LastLogon: \d{4}-\d{2}-\d{2}", ""

        # Append new value
        $NewDescription = ($NewDescription + " LastLogon: $LastLogonFormatted").Trim()

        # Update description
        Set-ADComputer -Identity $Computer `
            -Description $NewDescription -WhatIf

        # Disable computer
        Disable-ADAccount -Identity $Computer -WhatIf

        Write-Host "Disabled:" $Computer.Name "LastLogon:" $LastLogonFormatted
    }
}
