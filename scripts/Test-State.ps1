#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only report of this machine's state against catalog/items.json. Changes nothing.

.PARAMETER AsJson
    Emit one JSON document instead of the text report.

.NOTES
    Item status: present (still active, a profile could change it) | applied (already removed/disabled)
                 | not-present | not-applicable (wrong Windows build) | blocked (engine refuses: system package)
                 | unknown (could not be detected)
    Without elevation, Appx detection covers the current user only and cannot see provisioned packages.
    Exit codes: 0 ok | 1 unexpected error | 4 invalid catalog
#>
[CmdletBinding()]
param(
    [switch]$AsJson,
    [string]$CatalogPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'modules') -Filter *.psm1 |
    ForEach-Object { Import-Module $_.FullName -Force -Global -DisableNameChecking }
if (-not $CatalogPath) { $CatalogPath = Join-Path $repoRoot 'catalog\items.json' }

try {
    try { $catalog = Import-DebloatCatalog -Path $CatalogPath }
    catch { Write-Output "INVALID: $($_.Exception.Message)"; Write-Output 'EXIT_CODE=4'; exit 4 }
    $machine = Get-MachineInfo
    $statuses = @($catalog.items | ForEach-Object { Get-DebloatItemStatus -Item $_ -Machine $machine })
    $ai = @(Get-AIFeatureSummary -Statuses $statuses)

    $tierCounts = [ordered]@{}
    foreach ($tier in 'safe', 'moderate', 'aggressive', 'never-default') {
        $tierCounts[$tier] = @($statuses | Where-Object { $_.tier -eq $tier -and $_.status -eq 'present' }).Count
    }
    $statusCounts = [ordered]@{}
    foreach ($g in ($statuses | Group-Object status | Sort-Object Name)) { $statusCounts[$g.Name] = $g.Count }

    if ($AsJson) {
        [ordered]@{
            machine = $machine
            catalogSha256 = $catalog.sha256
            testedBuilds = @(Get-Prop $catalog 'testedBuilds' @())
            statusCounts = $statusCounts
            presentByTier = $tierCounts
            aiFeaturesPresent = $ai
            items = @($statuses | ForEach-Object {
                    [ordered]@{ id = $_.id; name = $_.name; category = $_.category; tier = $_.tier; status = $_.status; detail = $_.detail }
                })
        } | ConvertTo-Json -Depth 8
        exit 0
    }

    Write-Output "MACHINE=$($machine.computerName) $($machine.os) build $($machine.build).$($machine.ubr) $($machine.displayVersion) $($machine.edition) admin=$($machine.isAdmin)"
    $tested = @(Get-Prop $catalog 'testedBuilds' @())
    if ($tested.Count -gt 0 -and $tested -notcontains $machine.build) {
        Write-Output "WARNING: build $($machine.build) is not in the catalog's testedBuilds ($($tested -join ', ')). Identifiers may differ on this build."
    }
    if (-not $machine.isAdmin) { Write-Output 'NOTE: not elevated - Appx results cover the current user only; provisioned packages are not visible.' }
    Write-Output ''
    Write-Output ('{0,-15} {1,-10} {2,-14} {3,-46} {4}' -f 'STATUS', 'CATEGORY', 'TIER', 'ID', 'DETAIL')
    foreach ($s in ($statuses | Sort-Object @{ e = { $_.status -ne 'present' } }, category, id)) {
        Write-Output ('{0,-15} {1,-10} {2,-14} {3,-46} {4}' -f $s.status, $s.category, $s.tier, $s.id, $s.detail)
    }
    Write-Output ''
    Write-Output ('STATUS_COUNTS: ' + (@($statusCounts.Keys | ForEach-Object { "$_=$($statusCounts[$_])" }) -join ' '))
    Write-Output ('PRESENT_BY_TIER: ' + (@($tierCounts.Keys | ForEach-Object { "$_=$($tierCounts[$_])" }) -join ' '))
    Write-Output ('AI_FEATURES_PRESENT: ' + $ai.Count)
    foreach ($a in $ai) { Write-Output ("  {0} ({1}) - {2}" -f $a.id, $a.tier, $a.name) }
    exit 0
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    Write-Output 'EXIT_CODE=1'
    exit 1
}
