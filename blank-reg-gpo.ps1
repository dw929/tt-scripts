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

# Output file (timestamped)
$OutputFile = "GPO_Registry_Audit_$(Get-Date -Format yyyyMMdd_HHmmss).csv"

Write-Host "Scanning GPOs... this may take a moment..." -ForegroundColor Cyan

$Results = Get-GPO -All | ForEach-Object -Parallel {

    $gpo = $_

    try {
        [xml]$xmlgpo = $gpo | Get-GPOReport -ReportType XML

        foreach ($cn in $xmlgpo.GPO.ChildNodes) {

            if ($cn.ExtensionData.Name -notcontains "Windows Registry") { continue }

            $Registry = $cn.ExtensionData | Where-Object { $_.Name -eq "Windows Registry" }

            if (-not $Registry) { continue }

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

            $regentries = Get-RegistryEntries $Registry.FirstChild.RegistrySettings

            foreach ($reg in $regentries) {

                if ([string]::IsNullOrEmpty($reg.type)) {

                    [PSCustomObject]@{
                        GPO       = $gpo.DisplayName
                        Scope     = $cn.name
                        Action    = $reg.action
                        Hive      = $reg.hive
                        Key       = $reg.key
                        Name      = $reg.name
                        Type      = $reg.type
                        Value     = $reg.value
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed processing $($gpo.DisplayName)"
    }

} -ThrottleLimit 8

# Export automatically
$Results | Export-Csv $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host "Results exported to: $OutputFile" -ForegroundColor Yellow
