# Services.psm1 - service-disable / service-restore.
# Startup type is read from the service's registry key so delayed auto-start is preserved on revert.

function Get-ServiceStartup {
    param([Parameter(Mandatory)][string]$Name)
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $p = Get-ItemProperty -LiteralPath $key
    $start = Get-Prop $p 'Start'
    switch ($start) {
        2 { if ((Get-Prop $p 'DelayedAutostart' 0) -eq 1) { return 'AutomaticDelayedStart' } else { return 'Automatic' } }
        3 { return 'Manual' }
        4 { return 'Disabled' }
        default { return "Other($start)" }
    }
}

function Set-ServiceStartup {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Startup)
    $map = @{ Automatic = 'auto'; AutomaticDelayedStart = 'delayed-auto'; Manual = 'demand'; Disabled = 'disabled' }
    if (-not $map.ContainsKey($Startup)) { throw "Cannot set startup type '$Startup' for service '$Name'." }
    $r = Invoke-Native -FilePath "$env:SystemRoot\System32\sc.exe" -ArgumentList @('config', $Name, 'start=', $map[$Startup])
    if ($r.ExitCode -ne 0) { throw "sc.exe config $Name failed ($($r.ExitCode)): $($r.Output)" }
}

function Get-ServiceItemState {
    param([Parameter(Mandatory)]$Item)
    $name = [string]$Item.target.name
    $startup = Get-ServiceStartup -Name $name
    if ($null -eq $startup) {
        return [pscustomobject]@{ known = $true; present = $false; applied = $false; current = $null; detail = 'service not found' }
    }
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    $running = ($svc -and $svc.Status -eq 'Running')
    return [pscustomobject]@{
        known = $true; present = $true; applied = ($startup -eq $Item.detect.startup)
        current = [ordered]@{ startup = $startup; running = [bool]$running }
        detail = "startup = $startup, running = $running"
    }
}

function Invoke-ServiceItemRemove {
    param([Parameter(Mandatory)]$Item, $State)
    $name = [string]$Item.target.name
    Set-ServiceStartup -Name $name -Startup 'Disabled'
    $detail = 'startup set to Disabled'
    if ($State -and $State.current.running) {
        try { Stop-Service -Name $name -Force -ErrorAction Stop; $detail += ', stopped' }
        catch { $detail += ', still running until reboot' }
    }
    return @{ detail = $detail }
}

function Invoke-ServiceItemRevert {
    param([Parameter(Mandatory)]$Item, $Before)
    $name = [string]$Item.target.name
    $startup = [string](Get-Prop $Before 'startup')
    if (-not $startup -or $startup -like 'Other*') { $startup = [string]$Item.revert.defaultStartup }
    Set-ServiceStartup -Name $name -Startup $startup
    $detail = "startup restored to $startup"
    if (Get-Prop $Before 'running') {
        try { Start-Service -Name $name -ErrorAction Stop; $detail += ', started' }
        catch { $detail += ', will start on next boot/trigger' }
    }
    return @{ ok = $true; detail = $detail }
}

Export-ModuleMember -Function Get-ServiceItemState, Invoke-ServiceItemRemove, Invoke-ServiceItemRevert
