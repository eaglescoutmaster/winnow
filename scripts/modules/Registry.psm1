# Registry.psm1 - registry-set / registry-restore primitives (64-bit view, .NET API).
# HKCU can be redirected to another user's hive (HKEY_USERS\<SID>) when the script was elevated
# with different credentials than the interactive user.

$script:TargetSid = $null

function Set-RegistryTargetSid {
    param([string]$Sid)
    if ($Sid -and $Sid -notmatch '^S-1-[0-9-]+$') { throw "Invalid SID: $Sid" }
    $script:TargetSid = $Sid
}

function Resolve-RegistryTarget {
    param([Parameter(Mandatory)]$Target)
    $hive = [string](Get-Prop $Target 'hive')
    $path = [string](Get-Prop $Target 'path')
    $view = [Microsoft.Win32.RegistryView]::Registry64
    switch ($hive) {
        'HKLM' {
            return @{ Base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view); SubKey = $path; ExportPath = "HKLM\$path" }
        }
        'HKCU' {
            if ($script:TargetSid) {
                return @{ Base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::Users, $view); SubKey = "$($script:TargetSid)\$path"; ExportPath = "HKU\$($script:TargetSid)\$path" }
            }
            return @{ Base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, $view); SubKey = $path; ExportPath = "HKCU\$path" }
        }
        default { throw "Unsupported hive: $hive" }
    }
}

function Get-RegistryKeyInfo {
    param([Parameter(Mandatory)]$Target)
    $r = Resolve-RegistryTarget -Target $Target
    try {
        $key = $r.Base.OpenSubKey($r.SubKey, $false)
        $exists = ($null -ne $key)
        if ($key) { $key.Dispose() }
        return [pscustomobject]@{ exportPath = $r.ExportPath; keyExists = $exists }
    }
    finally { $r.Base.Dispose() }
}

function Get-RegistryValueInfo {
    param([Parameter(Mandatory)]$Target)
    $name = [string](Get-Prop $Target 'name')
    $r = Resolve-RegistryTarget -Target $Target
    try {
        $key = $r.Base.OpenSubKey($r.SubKey, $false)
        if ($null -eq $key) { return [ordered]@{ keyExists = $false; exists = $false; kind = $null; value = $null } }
        try {
            if (@($key.GetValueNames()) -notcontains $name) {
                return [ordered]@{ keyExists = $true; exists = $false; kind = $null; value = $null }
            }
            $kind = $key.GetValueKind($name).ToString()
            $value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            return [ordered]@{ keyExists = $true; exists = $true; kind = $kind; value = $value }
        }
        finally { $key.Dispose() }
    }
    finally { $r.Base.Dispose() }
}

function ConvertTo-RegistryData {
    param([string]$ValueType, $Value)
    switch ($ValueType) {
        'DWord' {
            $n = [int64]$Value
            if ($n -gt [int]::MaxValue) { return [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$n), 0) }
            return [int]$n
        }
        'QWord' { return [int64]$Value }
        'String' { return [string]$Value }
        'ExpandString' { return [string]$Value }
        default { throw "Unsupported registry value type: $ValueType" }
    }
}

function Test-RegistryDataEqual {
    param([string]$ValueType, $Expected, [string]$ActualKind, $Actual)
    if ($ValueType -ne $ActualKind) { return $false }
    if ($ValueType -in 'DWord', 'QWord') {
        return ((ConvertTo-RegistryData -ValueType $ValueType -Value $Expected) -eq (ConvertTo-RegistryData -ValueType $ValueType -Value $Actual))
    }
    return ([string]$Expected -eq [string]$Actual)
}

function Set-RegistryValueRaw {
    param([Parameter(Mandatory)]$Target, [string]$ValueType, $Value)
    $r = Resolve-RegistryTarget -Target $Target
    try {
        $key = $r.Base.CreateSubKey($r.SubKey)
        try {
            $key.SetValue([string](Get-Prop $Target 'name'), (ConvertTo-RegistryData -ValueType $ValueType -Value $Value), [Microsoft.Win32.RegistryValueKind]$ValueType)
        }
        finally { $key.Dispose() }
    }
    finally { $r.Base.Dispose() }
}

function Remove-RegistryValueRaw {
    # Deletes the value. If -RemoveEmptyKey is set and the key ends up with no values and no subkeys, deletes the key.
    param([Parameter(Mandatory)]$Target, [switch]$RemoveEmptyKey)
    $r = Resolve-RegistryTarget -Target $Target
    try {
        $key = $r.Base.OpenSubKey($r.SubKey, $true)
        if ($null -eq $key) { return }
        $empty = $false
        try {
            $key.DeleteValue([string](Get-Prop $Target 'name'), $false)
            $empty = ($key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0)
        }
        finally { $key.Dispose() }
        if ($RemoveEmptyKey -and $empty) { $r.Base.DeleteSubKey($r.SubKey, $false) }
    }
    finally { $r.Base.Dispose() }
}

function Get-RegistryItemState {
    param([Parameter(Mandatory)]$Item)
    $info = Get-RegistryValueInfo -Target $Item.target
    $applied = $false
    if ($info.exists) {
        $applied = Test-RegistryDataEqual -ValueType $Item.detect.valueType -Expected $Item.detect.value -ActualKind $info.kind -Actual $info.value
    }
    $detail = 'value not set'
    if ($info.exists) { $detail = "current = $($info.value) ($($info.kind))" }
    return [pscustomobject]@{ known = $true; present = $true; applied = $applied; current = $info; detail = $detail }
}

function Invoke-RegistryItemRemove {
    param([Parameter(Mandatory)]$Item, $State)
    Set-RegistryValueRaw -Target $Item.target -ValueType $Item.remove.valueType -Value $Item.remove.value
    return @{ detail = "set $($Item.target.hive)\$($Item.target.path)\$($Item.target.name) = $($Item.remove.value)" }
}

function Invoke-RegistryItemRevert {
    # Restores the logged prior state. Without a log entry, falls back to the catalog's revert.default
    # (present only where the Windows default is documented).
    param([Parameter(Mandatory)]$Item, $Before)
    $t = $Item.target
    if ($null -eq $Before) {
        $d = Get-Prop $Item.revert 'default'
        if ($null -eq $d) { throw "Item '$($Item.id)': no logged prior state and no documented default to restore." }
        if (Get-Prop $d 'absent') { $Before = @{ keyExists = $true; exists = $false } }
        else { $Before = @{ keyExists = $true; exists = $true; kind = (Get-Prop $d 'valueType'); value = (Get-Prop $d 'value') } }
    }
    if (Get-Prop $Before 'exists') {
        Set-RegistryValueRaw -Target $t -ValueType (Get-Prop $Before 'kind') -Value (Get-Prop $Before 'value')
        return @{ ok = $true; detail = "restored value $(Get-Prop $Before 'value')" }
    }
    Remove-RegistryValueRaw -Target $t -RemoveEmptyKey:(-not (Get-Prop $Before 'keyExists'))
    return @{ ok = $true; detail = 'removed value (was not set before)' }
}

Export-ModuleMember -Function Set-RegistryTargetSid, Get-RegistryKeyInfo, Get-RegistryValueInfo,
    Get-RegistryItemState, Invoke-RegistryItemRemove, Invoke-RegistryItemRevert
