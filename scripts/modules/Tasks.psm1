# Tasks.psm1 - task-disable / task-enable. Tasks are disabled, never deleted, so revert is exact.

function Get-TaskItemState {
    param([Parameter(Mandatory)]$Item)
    $t = Get-ScheduledTask -TaskPath $Item.target.taskPath -TaskName $Item.target.taskName -ErrorAction SilentlyContinue
    if ($null -eq $t) {
        return [pscustomobject]@{ known = $true; present = $false; applied = $false; current = $null; detail = 'task not found' }
    }
    $state = [string]$t.State
    return [pscustomobject]@{
        known = $true; present = $true; applied = ($state -eq 'Disabled')
        current = [ordered]@{ state = $state }; detail = "state = $state"
    }
}

function Invoke-TaskItemRemove {
    param([Parameter(Mandatory)]$Item, $State)
    Disable-ScheduledTask -TaskPath $Item.target.taskPath -TaskName $Item.target.taskName -ErrorAction Stop | Out-Null
    return @{ detail = 'task disabled' }
}

function Invoke-TaskItemRevert {
    param([Parameter(Mandatory)]$Item, $Before)
    if ((Get-Prop $Before 'state') -eq 'Disabled') { return @{ ok = $true; detail = 'was disabled before the run; left disabled' } }
    Enable-ScheduledTask -TaskPath $Item.target.taskPath -TaskName $Item.target.taskName -ErrorAction Stop | Out-Null
    return @{ ok = $true; detail = 'task enabled' }
}

Export-ModuleMember -Function Get-TaskItemState, Invoke-TaskItemRemove, Invoke-TaskItemRevert
