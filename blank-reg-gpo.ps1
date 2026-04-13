function Get-RegistryEntries {
    param ($Collection)

    $stack = @($Collection)

    while ($stack.Count -gt 0) {
        $item = $stack[0]
        $stack = if ($stack.Count -gt 1) { $stack[1..($stack.Count - 1)] } else { @() }

        if ($item.Registry) {
            $item.Registry.properties
        }

        if ($item.Collection) {
            $stack += $item.Collection
        }
    }
}

$OutputFile = "GPO_Registry_Audit_$(Get-Date -Format yyyyMMdd_HHmmss).csv"

$AllGPOs = Get-GPO -All
$total = $AllGPOs.Count
$index = 0

$Results = @()

Write-Host "Starting GPO Registry Audit..." -ForegroundColor Cyan
Write-Host "Total GPOs: $total" -ForegroundColor Cyan
Write-Host ""

foreach ($gpo in $AllGPOs) {

    $index++

    # Progress bar
    $percent = [math]::Round(($index / $total) * 100, 2)
    Write-Progress -Activity "Scanning GPOs" `
        -Status "$index / $total : $($gpo.DisplayName)" `
        -PercentComplete $percent

    Write-Host "[$index/$total] Processing: $($gpo.DisplayName)" -ForegroundColor Yellow

    try {
        [xml]$xmlgpo = $gpo | Get-GPOReport -ReportType XML

        $foundInGPO = 0

        foreach ($cn in $xmlgpo.GPO.ChildNodes) {

            if ($cn.ExtensionData.Name -notcontains "Windows Registry") { continue }

            $Registry = $cn.ExtensionData | Where-Object { $_.Name -eq "Windows Registry" }

            if (-not $Registry) { continue }

            Write-Verbose "  Found Windows Registry section in $($gpo.DisplayName)"

            $regentries = Get-RegistryEntries $Registry.FirstChild.RegistrySettings

            foreach ($reg in $regentries) {

                if ([string]::IsNullOrEmpty($reg.type)) {

                    $obj = [PSCustomObject]@{
                        GPO    = $gpo.DisplayName
                        Scope  = $cn.name
                        Action = $reg.action
                        Hive   = $reg.hive
                        Key    = $reg.key
                        Name   = $reg.name
                        Type   = $reg.type
                        Value  = $reg.value
                    }

                    # Store result
                    $Results += $obj
                    $foundInGPO++

                    # Live console output
                    Write-Host "    [FOUND] $($obj.Hive)\$($obj.Key)\$($obj.Name) = $($obj.Value)" -ForegroundColor Green
                }
            }
        }

        if ($foundInGPO -eq 0) {
            Write-Host "    No issues found" -ForegroundColor DarkGray
        }
        else {
            Write-Host "    -> $foundInGPO issue(s) found in this GPO" -ForegroundColor Red
        }

    }
    catch {
        Write-Host "    ERROR processing $($gpo.DisplayName)" -ForegroundColor Red
    }

    Write-Host ""
}

Write-Progress -Activity "Scanning GPOs" -Completed

# Export CSV
Write-Host "Exporting results to CSV..." -ForegroundColor Cyan
$Results | Export-Csv $OutputFile -NoTypeInformation -Encoding Unicode

Write-Host ""
Write-Host "DONE ✔" -ForegroundColor Green
Write-Host "Results saved to: $OutputFile" -ForegroundColor Yellow
Write-Host "Total issues found: $($Results.Count)" -ForegroundColor Cyan
