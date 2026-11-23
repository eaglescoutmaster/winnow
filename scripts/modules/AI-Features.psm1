# AI-Features.psm1 - feature-disable / feature-enable for Windows optional features that carry
# AI components, plus the AI summary used by Test-State.ps1.
# Detection uses CIM so it works without elevation; changes use the DISM cmdlets.

function Get-FeatureItemState {
    param([Parameter(Mandatory)]$Item)
    $name = [string]$Item.target.featureName
    if ($name -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid feature name: $name" }
    $f = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='$name'" -ErrorAction Stop
    if ($null -eq $f -or $f.InstallState -eq 3) {
        return [pscustomobject]@{ known = $true; present = $false; applied = $false; current = $null; detail = 'feature not available on this machine' }
    }
    $enabled = ($f.InstallState -eq 1)
    $label = 'disabled'
    if ($enabled) { $label = 'enabled' }
    return [pscustomobject]@{
        known = $true; present = $true; applied = (-not $enabled)
        current = [ordered]@{ installState = [int]$f.InstallState }; detail = "feature $label"
    }
}

function Invoke-FeatureItemRemove {
    param([Parameter(Mandatory)]$Item, $State)
    $r = Disable-WindowsOptionalFeature -Online -FeatureName $Item.target.featureName -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue
    return @{ detail = 'feature disabled'; restartNeeded = [bool]$r.RestartNeeded }
}

function Invoke-FeatureItemRevert {
    param([Parameter(Mandatory)]$Item, $Before)
    if ((Get-Prop $Before 'installState') -ne 1) { return @{ ok = $true; detail = 'was not enabled before the run; left as is' } }
    $r = Enable-WindowsOptionalFeature -Online -FeatureName $Item.target.featureName -NoRestart -All -ErrorAction Stop -WarningAction SilentlyContinue
    return @{ ok = $true; detail = 'feature enabled'; restartNeeded = [bool]$r.RestartNeeded }
}

function Get-AIFeatureSummary {
    # Input: status objects from Get-DebloatItemStatus. Output: AI items still active on this machine.
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Statuses)
    return @($Statuses | Where-Object { $_.category -eq 'ai' -and $_.status -eq 'present' } |
            ForEach-Object { [ordered]@{ id = $_.id; name = $_.name; tier = $_.tier; detail = $_.detail } })
}

Export-ModuleMember -Function Get-FeatureItemState, Invoke-FeatureItemRemove, Invoke-FeatureItemRevert, Get-AIFeatureSummary
