# Appx.psm1 - appx-remove / appx-reinstall.
# Removal: every installed copy (all users when elevated) plus the provisioned package, so new
# user profiles do not get it back. Revert is best effort; see Invoke-AppxItemRevert.

$script:Inventory = $null

function Reset-AppxInventory { $script:Inventory = $null }

function Get-AppxInventory {
    if ($script:Inventory) { return $script:Inventory }
    $admin = Test-IsAdmin
    $packages = @(); $provisioned = @(); $failed = $false; $message = ''
    try {
        if ($admin) { $packages = @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
        else { $packages = @(Get-AppxPackage -ErrorAction Stop) }
    }
    catch { $failed = $true; $message = $_.Exception.Message }
    if ($admin -and -not $failed) {
        try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }
        catch { $failed = $true; $message = $_.Exception.Message }
    }
    $script:Inventory = [pscustomobject]@{
        Packages = $packages; Provisioned = $provisioned; Partial = (-not $admin); Failed = $failed; Message = $message
    }
    return $script:Inventory
}

function Get-AppxItemState {
    param([Parameter(Mandatory)]$Item)
    $name = [string]$Item.target.packageName
    $inv = Get-AppxInventory
    if ($inv.Failed) {
        return [pscustomobject]@{ known = $false; present = $false; applied = $false; current = $null; detail = "Appx query failed: $($inv.Message)" }
    }
    $pk = @($inv.Packages | Where-Object { $_.Name -eq $name })
    $pv = @($inv.Provisioned | Where-Object { $_.DisplayName -eq $name })
    $current = [ordered]@{
        packages    = @($pk | ForEach-Object { [ordered]@{ fullName = $_.PackageFullName; version = [string]$_.Version; installLocation = [string]$_.InstallLocation; nonRemovable = [bool]$_.NonRemovable } })
        provisioned = @($pv | ForEach-Object { [string]$_.PackageName })
        partial     = $inv.Partial
    }
    $present = ($pk.Count -gt 0 -or $pv.Count -gt 0)
    $detail = 'not installed'
    if ($present) { $detail = "installed: $($pk.Count), provisioned: $($pv.Count)" }
    if ($inv.Partial) { $detail += ' (current user only; run elevated for all users + provisioned)' }
    # Hard refusal, independent of the catalog: system-signed, non-removable and framework packages.
    $blocked = $false
    foreach ($p in $pk) {
        if ($p.NonRemovable -or $p.IsFramework -or ([string]$p.SignatureKind -eq 'System')) { $blocked = $true }
    }
    if ($blocked) { $detail = 'refused: package is system-signed, non-removable or a framework' }
    return [pscustomobject]@{ known = $true; present = $present; applied = (-not $present); blocked = $blocked; current = $current; detail = $detail }
}

function Invoke-AppxItemRemove {
    param([Parameter(Mandatory)]$Item, [Parameter(Mandatory)]$State)
    $removed = 0; $deprovisioned = 0
    try {
        foreach ($prov in @($State.current.provisioned)) {
            Remove-AppxProvisionedPackage -Online -PackageName $prov -ErrorAction Stop | Out-Null
            $deprovisioned++
        }
        foreach ($p in @($State.current.packages)) {
            Remove-AppxPackage -Package $p.fullName -AllUsers -ErrorAction Stop
            $removed++
        }
    }
    finally { Reset-AppxInventory }
    return @{ detail = "removed $removed package(s), deprovisioned $deprovisioned" }
}

function Invoke-AppxItemRevert {
    # Order of attempts:
    #   1. re-register from a manifest still on disk (works when the package files were kept)
    #   2. winget install from the Microsoft Store source, if the catalog gives a storeId
    #   3. report manual action. Re-provisioning for new users is not restored.
    param([Parameter(Mandatory)]$Item, $Before)
    Reset-AppxInventory
    $state = Get-AppxItemState -Item $Item
    if ($state.known -and $state.present) { return @{ ok = $true; detail = 'already installed' } }

    foreach ($p in @(Get-Prop $Before 'packages' @())) {
        $loc = [string](Get-Prop $p 'installLocation')
        if (-not $loc) { continue }
        $manifest = Join-Path $loc 'AppxManifest.xml'
        if (Test-Path -LiteralPath $manifest) {
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
                Reset-AppxInventory
                return @{ ok = $true; detail = "re-registered from $manifest" }
            }
            catch { }
        }
    }

    $storeId = [string](Get-Prop $Item.revert 'storeId')
    if ($storeId) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($winget) {
            $r = Invoke-Native -FilePath $winget.Source -ArgumentList @('install', '--id', $storeId, '--source', 'msstore', '--accept-package-agreements', '--accept-source-agreements', '--silent')
            Reset-AppxInventory
            if ($r.ExitCode -eq 0) { return @{ ok = $true; detail = "reinstalled via winget (msstore $storeId)" } }
        }
        return @{ ok = $false; manual = $true; detail = "Reinstall from the Microsoft Store: https://apps.microsoft.com/detail/$storeId" }
    }
    return @{ ok = $false; manual = $true; detail = "Reinstall '$($Item.target.packageName)' from the Microsoft Store (no store id in catalog)." }
}

Export-ModuleMember -Function Reset-AppxInventory, Get-AppxItemState, Invoke-AppxItemRemove, Invoke-AppxItemRevert
