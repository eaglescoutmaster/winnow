# Common.psm1 - catalog loading/validation, item selection, state dispatch, logging, backups.
# ASCII only. Compatible with Windows PowerShell 5.1.

$script:Tiers      = @('safe', 'moderate', 'aggressive', 'never-default')
$script:Categories = @('appx', 'ai', 'widgets', 'telemetry', 'edge', 'onedrive', 'ads', 'search')
$script:Tags       = @('gaming', 'office', 'onedrive', 'edge')
$script:Recur      = @('yes', 'no', 'sometimes', 'unknown')
$script:RegTypes   = @('DWord', 'QWord', 'String', 'ExpandString')
$script:Startups   = @('Automatic', 'AutomaticDelayedStart', 'Manual')

# remove.op -> family description. This is the only dispatch table; removal targets live in the catalog.
$script:Families = @{
    'appx-remove'     = @{ Family = 'Appx';        Detect = 'appx-absent';      Revert = 'appx-reinstall';   Target = @('packageName');          State = 'Get-AppxItemState';     Remove = 'Invoke-AppxItemRemove';     Undo = 'Invoke-AppxItemRevert' }
    'registry-set'    = @{ Family = 'Registry';    Detect = 'registry-equals';  Revert = 'registry-restore'; Target = @('hive', 'path', 'name'); State = 'Get-RegistryItemState'; Remove = 'Invoke-RegistryItemRemove'; Undo = 'Invoke-RegistryItemRevert' }
    'policy-set'      = @{ Family = 'Policies';    Detect = 'registry-equals';  Revert = 'policy-restore';   Target = @('hive', 'path', 'name'); State = 'Get-PolicyItemState';   Remove = 'Invoke-PolicyItemRemove';   Undo = 'Invoke-PolicyItemRevert' }
    'service-disable' = @{ Family = 'Services';    Detect = 'service-startup';  Revert = 'service-restore';  Target = @('name');                 State = 'Get-ServiceItemState';  Remove = 'Invoke-ServiceItemRemove';  Undo = 'Invoke-ServiceItemRevert' }
    'task-disable'    = @{ Family = 'Tasks';       Detect = 'task-disabled';    Revert = 'task-enable';      Target = @('taskPath', 'taskName'); State = 'Get-TaskItemState';     Remove = 'Invoke-TaskItemRemove';     Undo = 'Invoke-TaskItemRevert' }
    'feature-disable' = @{ Family = 'AI-Features'; Detect = 'feature-disabled'; Revert = 'feature-enable';   Target = @('featureName');          State = 'Get-FeatureItemState';  Remove = 'Invoke-FeatureItemRemove';  Undo = 'Invoke-FeatureItemRevert' }
}

function Get-Prop {
    # Safe property read for PSCustomObject (from JSON) and hashtables alike.
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -ne $p) { return $p.Value }
    return $Default
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-MachineInfo {
    $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int](Get-Prop $cv 'CurrentBuildNumber' 0)
    $os = 'win10'
    if ($build -ge 22000) { $os = 'win11' }
    $domainJoined = $false
    try { $domainJoined = [bool](Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).PartOfDomain } catch { }
    return [pscustomobject][ordered]@{
        domainJoined   = $domainJoined
        computerName   = $env:COMPUTERNAME
        os             = $os
        build          = $build
        ubr            = [int](Get-Prop $cv 'UBR' 0)
        displayVersion = [string](Get-Prop $cv 'DisplayVersion' '')
        edition        = [string](Get-Prop $cv 'EditionID' '')
        psVersion      = $PSVersionTable.PSVersion.ToString()
        psEdition      = [string]$PSVersionTable.PSEdition
        isAdmin        = (Test-IsAdmin)
        user           = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
}

function Invoke-Native {
    # Runs a native executable without letting stderr become a PowerShell error. Returns exit code + output.
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$ArgumentList)
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ((Get-Content -LiteralPath $out -Raw), (Get-Content -LiteralPath $err -Raw) | Where-Object { $_ }) -join "`n"
        return [pscustomobject]@{ ExitCode = $p.ExitCode; Output = [string]$text }
    }
    finally {
        Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Save-JsonFile {
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $Object | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

function New-DebloatRunId {
    return ('{0}-{1:x4}' -f (Get-Date).ToString('yyyyMMdd-HHmmss'), (Get-Random -Maximum 65535))
}

function Get-DebloatFamily {
    param([Parameter(Mandatory)]$Item)
    $op = [string](Get-Prop (Get-Prop $Item 'remove') 'op' '')
    if ($script:Families.ContainsKey($op)) { return $script:Families[$op] }
    return $null
}

function Test-ProtectedTarget {
    param([Parameter(Mandatory)]$Item, $Protected)
    if ($null -eq $Protected) { return $false }
    $t = Get-Prop $Item 'target'
    $pkg = Get-Prop $t 'packageName'
    if ($pkg) {
        foreach ($pat in @(Get-Prop $Protected 'appx' @())) { if ($pkg -like $pat) { return $true } }
    }
    $fam = Get-DebloatFamily -Item $Item
    if ($fam -and $fam.Family -eq 'Services') {
        foreach ($pat in @(Get-Prop $Protected 'services' @())) { if ((Get-Prop $t 'name') -like $pat) { return $true } }
    }
    $feat = Get-Prop $t 'featureName'
    if ($feat -and (@(Get-Prop $Protected 'features' @()) -contains $feat)) { return $true }
    return $false
}

function Test-DebloatCatalog {
    # Structural validation that works on PowerShell 5.1 (no Test-Json). Returns an array of error strings.
    param([Parameter(Mandatory)]$Catalog)
    $e = New-Object System.Collections.Generic.List[string]
    if ((Get-Prop $Catalog 'schemaVersion') -ne 1) { $e.Add('schemaVersion must be 1') }
    $items = @(Get-Prop $Catalog 'items' @())
    if ($items.Count -eq 0) { $e.Add('items must be a non-empty array') }
    $protected = Get-Prop $Catalog 'protected'
    $seen = @{}
    foreach ($it in $items) {
        $id = [string](Get-Prop $it 'id' '')
        $p = "item '$id':"
        if ($id -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $e.Add("$p id must be kebab-case") }
        if ($seen.ContainsKey($id)) { $e.Add("$p duplicate id") } else { $seen[$id] = $true }
        if (-not (Get-Prop $it 'name')) { $e.Add("$p name missing") }
        if ($script:Categories -notcontains (Get-Prop $it 'category')) { $e.Add("$p invalid category") }
        $tier = Get-Prop $it 'tier'
        if ($script:Tiers -notcontains $tier) { $e.Add("$p invalid tier") }
        foreach ($tag in @(Get-Prop $it 'tags' @())) { if ($script:Tags -notcontains $tag) { $e.Add("$p invalid tag '$tag'") } }
        if ($script:Recur -notcontains (Get-Prop $it 'returnsAfterFeatureUpdate')) { $e.Add("$p invalid returnsAfterFeatureUpdate") }

        $b = Get-Prop $it 'builds'
        $os = @(Get-Prop $b 'os' @())
        if ($os.Count -eq 0) { $e.Add("$p builds.os missing") }
        foreach ($o in $os) { if (@('win10', 'win11') -notcontains $o) { $e.Add("$p invalid builds.os '$o'") } }
        $min = Get-Prop $b 'minBuild'
        $max = Get-Prop $b 'maxBuild'
        if ($null -eq $min -or $min -isnot [ValueType]) { $e.Add("$p builds.minBuild must be a number") }
        if ($null -ne $max -and ($max -isnot [ValueType] -or $max -lt $min)) { $e.Add("$p builds.maxBuild must be null or >= minBuild") }

        $src = @(Get-Prop $it 'sources' @())
        if ($src.Count -eq 0) { $e.Add("$p needs at least one source") }
        foreach ($s in $src) { if ([string]$s -notmatch '^https://') { $e.Add("$p source is not an https URL: $s") } }

        $fam = Get-DebloatFamily -Item $it
        if ($null -eq $fam) { $e.Add("$p unknown remove.op"); continue }
        $detect = Get-Prop $it 'detect'; $remove = Get-Prop $it 'remove'; $revert = Get-Prop $it 'revert'
        if ((Get-Prop $detect 'op') -ne $fam.Detect) { $e.Add("$p detect.op must be '$($fam.Detect)'") }
        if ((Get-Prop $revert 'op') -ne $fam.Revert) { $e.Add("$p revert.op must be '$($fam.Revert)'") }
        $t = Get-Prop $it 'target'
        foreach ($f in $fam.Target) { if (-not (Get-Prop $t $f)) { $e.Add("$p target.$f missing") } }

        switch ($fam.Family) {
            { $_ -in 'Registry', 'Policies' } {
                if (@('HKLM', 'HKCU') -notcontains (Get-Prop $t 'hive')) { $e.Add("$p target.hive must be HKLM or HKCU") }
                $path = [string](Get-Prop $t 'path' '')
                if ($path -match '^(\\|HK)') { $e.Add("$p target.path must be relative to the hive") }
                $vt = Get-Prop $detect 'valueType'
                if ($script:RegTypes -notcontains $vt) { $e.Add("$p detect.valueType invalid") }
                if ((Get-Prop $remove 'valueType') -ne $vt) { $e.Add("$p remove.valueType differs from detect.valueType") }
                if ([string](Get-Prop $remove 'value') -ne [string](Get-Prop $detect 'value')) { $e.Add("$p remove.value differs from detect.value") }
                if ($null -eq (Get-Prop $remove 'value')) { $e.Add("$p remove.value missing") }
                $d = Get-Prop $revert 'default'
                if ($null -ne $d -and -not (Get-Prop $d 'absent') -and ($script:RegTypes -notcontains (Get-Prop $d 'valueType') -or $null -eq (Get-Prop $d 'value'))) {
                    $e.Add("$p revert.default must be {absent:true} or {valueType,value}")
                }
                if ($fam.Family -eq 'Policies' -and $path -notmatch '^SOFTWARE\\(Policies\\|Microsoft\\Windows\\CurrentVersion\\Policies\\)') {
                    $e.Add("$p policy-set path must be under a Policies key")
                }
            }
            'Services' {
                if ((Get-Prop $detect 'startup') -ne 'Disabled') { $e.Add("$p detect.startup must be 'Disabled'") }
                if ($script:Startups -notcontains (Get-Prop $revert 'defaultStartup')) { $e.Add("$p revert.defaultStartup invalid") }
            }
            'Tasks' {
                $tp = [string](Get-Prop $t 'taskPath' '')
                if ($tp -notmatch '^\\.*\\$' -and $tp -ne '\') { $e.Add("$p target.taskPath must start and end with a backslash") }
            }
        }
        if ($tier -ne 'never-default' -and (Test-ProtectedTarget -Item $it -Protected $protected)) {
            $e.Add("$p targets a protected identifier and must be tier never-default")
        }
    }
    return $e.ToArray()
}

function Import-DebloatCatalog {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Catalog not found: $Path" }
    $cat = Read-JsonFile -Path $Path
    $errors = @(Test-DebloatCatalog -Catalog $cat)
    if ($errors.Count -gt 0) { throw ("Catalog invalid:`n  " + ($errors -join "`n  ")) }
    $cat | Add-Member -NotePropertyName sha256 -NotePropertyValue (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -Force
    return $cat
}

function Select-DebloatItems {
    # Profile tiers are cumulative. never-default items are only ever selected by explicit -Only.
    param([Parameter(Mandatory)]$Catalog, [string]$ProfileName = 'safe', [string[]]$Only, [string[]]$Exclude)
    $items = @($Catalog.items)
    if ($Only -and $Only.Count -gt 0) {
        $known = @($items | ForEach-Object { $_.id })
        $unknown = @($Only | Where-Object { $known -notcontains $_ })
        if ($unknown.Count -gt 0) { throw [System.ArgumentException]("Unknown item id(s): " + ($unknown -join ', ')) }
        return @($items | Where-Object { $Only -contains $_.id })
    }
    $tiers = switch ($ProfileName) {
        'safe' { @('safe') }
        'moderate' { @('safe', 'moderate') }
        'aggressive' { @('safe', 'moderate', 'aggressive') }
        default { throw [System.ArgumentException]("Unknown profile: $ProfileName") }
    }
    $selected = @($items | Where-Object { $tiers -contains $_.tier })
    if ($Exclude -and $Exclude.Count -gt 0) {
        $selected = @($selected | Where-Object {
                $tags = @(Get-Prop $_ 'tags' @())
                -not (@($tags | Where-Object { $Exclude -contains $_ }).Count)
            })
    }
    return $selected
}

function Test-ItemApplicable {
    param([Parameter(Mandatory)]$Item, [Parameter(Mandatory)]$Machine)
    $b = $Item.builds
    if (@($b.os) -notcontains $Machine.os) { return $false }
    if ($Machine.build -lt $b.minBuild) { return $false }
    $max = Get-Prop $b 'maxBuild'
    if ($null -ne $max -and $Machine.build -gt $max) { return $false }
    return $true
}

function Get-DebloatItemStatus {
    # status: present (would be changed) | applied | not-present | not-applicable | blocked | unknown
    param([Parameter(Mandatory)]$Item, [Parameter(Mandatory)]$Machine)
    $fam = Get-DebloatFamily -Item $Item
    $status = 'unknown'; $detail = ''; $state = $null
    if (-not (Test-ItemApplicable -Item $Item -Machine $Machine)) {
        $status = 'not-applicable'; $detail = "build $($Machine.build) outside item range"
    }
    else {
        try {
            $state = & $fam.State -Item $Item
            $detail = [string]$state.detail
            if (-not $state.known) { $status = 'unknown' }
            elseif (-not $state.present) { $status = 'not-present' }
            elseif (Get-Prop $state 'blocked') { $status = 'blocked' }
            elseif ($state.applied) { $status = 'applied' }
            else { $status = 'present' }
        }
        catch { $status = 'unknown'; $detail = $_.Exception.Message }
    }
    return [pscustomobject][ordered]@{
        id = $Item.id; name = $Item.name; category = $Item.category; tier = $Item.tier
        family = $fam.Family; op = $Item.remove.op; status = $status; detail = $detail
        state = $state; item = $Item
    }
}

function Get-PlanHash {
    param([string]$CatalogSha, [string]$Computer, [string[]]$Ids)
    $text = $CatalogSha + '|' + $Computer + '|' + ((@($Ids) | Sort-Object) -join ',')
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) -replace '-', '') }
    finally { $sha.Dispose() }
}

function New-DebloatRestorePoint {
    # Creates a System Restore point and verifies it exists. Throws if no usable restore point results.
    # Windows throttles restore point creation (default: one per 24h); a restore point created inside
    # that window is accepted and reported as reused.
    param([Parameter(Mandatory)][string]$Description, [switch]$EnableSystemRestore)
    if ($PSVersionTable.PSEdition -eq 'Core') { throw 'Restore points need Windows PowerShell 5.1 (powershell.exe), not pwsh.' }
    if ($EnableSystemRestore) { Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop }
    $before = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
    $maxSeq = 0
    foreach ($rp in $before) { if ($rp.SequenceNumber -gt $maxSeq) { $maxSeq = $rp.SequenceNumber } }
    $cpError = ''
    try {
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue
    }
    catch { $cpError = $_.Exception.Message }
    $after = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Sort-Object SequenceNumber)
    $new = @($after | Where-Object { $_.SequenceNumber -gt $maxSeq }) | Select-Object -Last 1
    if ($new) {
        return [ordered]@{ created = $true; reused = $false; sequenceNumber = $new.SequenceNumber; description = $new.Description }
    }
    $last = $after | Select-Object -Last 1
    if ($last) {
        $when = [Management.ManagementDateTimeConverter]::ToDateTime($last.CreationTime)
        if (((Get-Date) - $when).TotalHours -lt 24) {
            return [ordered]@{ created = $false; reused = $true; sequenceNumber = $last.SequenceNumber; description = $last.Description; createdAt = $when.ToString('o') }
        }
    }
    throw ("No restore point could be created or verified. $cpError " +
        "System Restore may be disabled; enable it for the system drive (or re-run with -EnableSystemRestore) and try again.").Trim()
}

function Backup-DebloatRegistry {
    # Exports every distinct registry key the run will touch. Keys that do not exist yet are recorded as absent.
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items, [Parameter(Mandatory)][string]$Dir)
    $result = [ordered]@{ dir = $Dir; files = @() }
    $keys = @{}
    foreach ($it in $Items) {
        $fam = Get-DebloatFamily -Item $it
        if ($fam -and $fam.Family -in 'Registry', 'Policies') {
            $info = Get-RegistryKeyInfo -Target $it.target
            $keys[$info.exportPath] = $info
        }
    }
    if ($keys.Count -eq 0) { return $result }
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $n = 0
    foreach ($k in ($keys.Keys | Sort-Object)) {
        $n++
        if (-not $keys[$k].keyExists) {
            $result.files += [ordered]@{ key = $k; existed = $false; file = $null }
            continue
        }
        $file = Join-Path $Dir ('{0:d3}.reg' -f $n)
        $r = Invoke-Native -FilePath "$env:SystemRoot\System32\reg.exe" -ArgumentList @('export', ('"' + $k + '"'), ('"' + $file + '"'), '/y')
        if ($r.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $file)) {
            throw "Registry export failed for '$k': $($r.Output)"
        }
        $result.files += [ordered]@{ key = $k; existed = $true; file = $file }
    }
    return $result
}

Export-ModuleMember -Function Get-Prop, Test-IsAdmin, Get-MachineInfo, Invoke-Native, Read-JsonFile, Save-JsonFile,
    New-DebloatRunId, Get-DebloatFamily, Test-ProtectedTarget, Test-DebloatCatalog, Import-DebloatCatalog,
    Select-DebloatItems, Test-ItemApplicable, Get-DebloatItemStatus, Get-PlanHash, New-DebloatRestorePoint,
    Backup-DebloatRegistry
