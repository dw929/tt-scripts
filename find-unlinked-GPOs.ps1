Import-Module GroupPolicy

$AllGPOs = Get-GPO -All

$UnlinkedGPOs = foreach ($GPO in $AllGPOs) {

    $Links = (Get-GPOReport -Guid $GPO.Id -ReportType Xml |
              Select-String "<SOMPath>")

    if (-not $Links) {
        [PSCustomObject]@{
            Name = $GPO.DisplayName
            ID   = $GPO.Id
        }
    }
}

$UnlinkedGPOs | Sort-Object Name 
