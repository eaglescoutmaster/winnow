# Policies.psm1 - policy-set / policy-restore. Same primitives as Registry.psm1, but refuses any
# path that is not under a Policies key, so a catalog typo cannot turn a policy item into an
# arbitrary registry write.

function Assert-PolicyPath {
    param([Parameter(Mandatory)]$Item)
    $path = [string]$Item.target.path
    if ($path -notmatch '^SOFTWARE\\(Policies\\|Microsoft\\Windows\\CurrentVersion\\Policies\\)') {
        throw "Item '$($Item.id)': '$path' is not a policy path."
    }
}

function Get-PolicyItemState {
    param([Parameter(Mandatory)]$Item)
    Assert-PolicyPath -Item $Item
    return (Get-RegistryItemState -Item $Item)
}

function Invoke-PolicyItemRemove {
    param([Parameter(Mandatory)]$Item, $State)
    Assert-PolicyPath -Item $Item
    return (Invoke-RegistryItemRemove -Item $Item -State $State)
}

function Invoke-PolicyItemRevert {
    param([Parameter(Mandatory)]$Item, $Before)
    Assert-PolicyPath -Item $Item
    return (Invoke-RegistryItemRevert -Item $Item -Before $Before)
}

Export-ModuleMember -Function Get-PolicyItemState, Invoke-PolicyItemRemove, Invoke-PolicyItemRevert
