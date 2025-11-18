param(
  [string]$ResourceGroup = $env:RG_SOURCE
)

$resources = az resource list -g $ResourceGroup -o json | ConvertFrom-Json
$rows = @()

foreach ($r in $resources) {
  $row = [pscustomobject]@{
    resourceId   = $r.id
    resourceType = $r.type
    location     = $r.location
    tag_Owner    = if ($r.tags) { $r.tags.Owner } else { "" }
    tag_Lab      = if ($r.tags) { $r.tags.Lab } else { "" }
    tag_Scenario = if ($r.tags) { $r.tags.Scenario } else { "" }
  }
  $rows += $row
}

$rows | Export-Csv -NoTypeInformation -Path "docs/source-inventory-ps.csv"
Write-Host "Inventory written to docs/source-inventory-ps.csv"
