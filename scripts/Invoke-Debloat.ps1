#Requires -Version 5.1
<#
.SYNOPSIS
    Data-driven Windows debloat. Reads catalog/items.json; contains no removal lists of its own.

.DESCRIPTION
    One-shot use: -Auto applies the aggressive profile with no questions (elevates, turns on System
    Restore if needed, accepts an untested build). Without -Auto or -Apply it is a dry run: it prints
    a plan, writes it to logs/plan-<id>.json and changes nothing.
    Real changes need an elevated Windows PowerShell 5.1 session (or -Elevate), a restore
    point and a registry export. Every change is written to logs/run-<id>.json, which -Revert uses.

.PARAMETER Profile
    safe | moderate | aggressive (default). Tiers are cumulative. never-default items are never selected by a profile.
.PARAMETER Auto
    Unattended run: same as -Apply -Elevate -EnableSystemRestore -AllowUntestedBuild. No plan file or approval step.
.PARAMETER DryRun
    Explicit dry run (this is already the default).
.PARAMETER Apply
    Make changes. Without it nothing is modified, including for -Revert.
.PARAMETER Revert
    Path to a logs/run-*.json file. Undoes that run (dry run unless -Apply is also given).
.PARAMETER Only
    Item ids to act on, ignoring profile tiers. The only way to select never-default items.
.PARAMETER Exclude
    Tags to leave alone: gaming, office, onedrive, edge.
.PARAMETER Plan
    Path to a plan file from a dry run. With -Apply, the selection comes from the plan and only items the plan
    listed as CHANGE are touched. The run aborts if the catalog changed or the plan is from another machine.
.PARAMETER Elevate
    With -Apply from a non-elevated shell: relaunch elevated (UAC prompt), wait, then print the run log summary.
.PARAMETER EnableSystemRestore
    Turn on System Restore for the system drive before creating the restore point.
.PARAMETER AllowUntestedBuild
    Permit -Apply on a Windows build that is not listed in the catalog's testedBuilds.

.NOTES
    Exit codes: 0 ok | 1 unexpected error | 2 precondition failed, nothing changed | 3 completed with failures | 4 invalid input or catalog
#>
[CmdletBinding()]
param(
    [Alias('Profile')]
    [ValidateSet('safe', 'moderate', 'aggressive')]
    [string]$ProfileName = 'aggressive',
    [switch]$Auto,
    [switch]$DryRun,
    [switch]$Apply,
    [string]$Revert,
    [string[]]$Only,
    [string[]]$Exclude,
    [string]$Plan,
    [switch]$Elevate,
    [switch]$EnableSystemRestore,
    [switch]$AllowUntestedBuild,
    [string]$CatalogPath,
    [string]$LogDir,
    [string]$TargetUserSid,
    [string]$RunId
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'modules') -Filter *.psm1 |
    ForEach-Object { Import-Module $_.FullName -Force -Global -DisableNameChecking }

if (-not $CatalogPath) { $CatalogPath = Join-Path $repoRoot 'catalog\items.json' }
if (-not $LogDir) { $LogDir = Join-Path $repoRoot 'logs' }
if (-not $RunId) { $RunId = New-DebloatRunId }
$LogDir = $LogDir.TrimEnd('\')

function Split-List {
    param([string[]]$Value)
    return @($Value | Where-Object { $_ } | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Stop-Run {
    param([int]$Code, [string]$Message)
    if ($Message) { Write-Output $Message }
    Write-Output "EXIT_CODE=$Code"
    exit $Code
}

function Get-ActionLabel {
    param([string]$Status)
    switch ($Status) {
        'present' { 'CHANGE' }
        'applied' { 'skip:done' }
        'not-present' { 'skip:absent' }
        'not-applicable' { 'skip:n/a' }
        'blocked' { 'skip:blocked' }
        'not-in-plan' { 'skip:unplanned' }
        default { 'skip:unknown' }
    }
}

function Write-PlanTable {
    param([object[]]$Entries)
    Write-Output ('{0,-13} {1,-14} {2,-46} {3}' -f 'ACTION', 'TIER', 'ID', 'DETAIL')
    foreach ($e in $Entries) {
        Write-Output ('{0,-13} {1,-14} {2,-46} {3}' -f (Get-ActionLabel $e.status), $e.tier, $e.id, $e.detail)
    }
}

function Write-LogSummary {
    param([string]$Path)
    $l = Read-JsonFile -Path $Path
    Write-Output "RUN_ID=$($l.runId)"
    Write-Output "OUTCOME=$($l.outcome)"
    if ($l.abortReason) { Write-Output "ABORT_REASON=$($l.abortReason)" }
    $changes = @($l.changes)
    foreach ($g in ($changes | Group-Object status | Sort-Object Name)) { Write-Output ("COUNT {0} = {1}" -f $g.Name, $g.Count) }
    foreach ($c in ($changes | Where-Object { $_.status -notlike 'skipped-*' })) {
        Write-Output ('{0,-24} {1,-46} {2}' -f $c.status, $c.id, $c.detail)
    }
    if ($l.restartRecommended) { Write-Output 'RESTART_RECOMMENDED=true' }
    Write-Output "LOG_FILE=$Path"
}

function Invoke-ElevatedSelf {
    param([string]$RevertPath)
    function Q([string]$s) { '"' + $s + '"' }
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Q $PSCommandPath), '-Apply',
        '-RunId', $RunId, '-TargetUserSid', $sid, '-LogDir', (Q $LogDir), '-CatalogPath', (Q $CatalogPath))
    if ($RevertPath) { $a += @('-Revert', (Q $RevertPath)) }
    else {
        $a += @('-Profile', $ProfileName)
        if ($Only.Count) { $a += @('-Only', ($Only -join ',')) }
        if ($Exclude.Count) { $a += @('-Exclude', ($Exclude -join ',')) }
        if ($Plan) { $a += @('-Plan', (Q $Plan)) }
    }
    if ($EnableSystemRestore) { $a += '-EnableSystemRestore' }
    if ($AllowUntestedBuild) { $a += '-AllowUntestedBuild' }
    $exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    try { $p = Start-Process -FilePath $exe -ArgumentList $a -Verb RunAs -Wait -PassThru }
    catch { Stop-Run 2 "PRECONDITION: elevation was declined or failed: $($_.Exception.Message)" }
    $logPath = Join-Path $LogDir "run-$RunId.json"
    if (Test-Path -LiteralPath $logPath) { Write-LogSummary -Path $logPath }
    else { Write-Output 'The elevated process wrote no log.' }
    Stop-Run $p.ExitCode ''
}

function Save-Log { Save-JsonFile -Object $script:log -Path $script:logPath }

function Start-ApplyRun {
    # Shared preamble for real runs: log skeleton, restore point, registry export. Aborts with exit 2 on failure.
    param([string]$Kind, [object[]]$RegistryItems, [hashtable]$Extra)
    $script:logPath = Join-Path $LogDir "run-$RunId.json"
    $script:log = [ordered]@{
        schema = 1; runId = $RunId; kind = $Kind; startedAt = (Get-Date).ToString('o'); finishedAt = $null
        outcome = 'in-progress'; abortReason = $null; machine = $machine; targetUserSid = $TargetUserSid
        catalogSha256 = $catalog.sha256; restorePoint = $null; registryBackup = $null
        restartRecommended = $false; changes = @()
    }
    foreach ($k in $Extra.Keys) { $script:log[$k] = $Extra[$k] }
    Save-Log
    try {
        $script:log.restorePoint = New-DebloatRestorePoint -Description "windows-debloat $RunId" -EnableSystemRestore:$EnableSystemRestore
        $script:log.registryBackup = Backup-DebloatRegistry -Items $RegistryItems -Dir (Join-Path $LogDir "backup-$RunId")
        Save-Log
    }
    catch {
        $script:log.outcome = 'aborted'; $script:log.abortReason = $_.Exception.Message
        $script:log.finishedAt = (Get-Date).ToString('o'); Save-Log
        Write-Output "LOG_FILE=$($script:logPath)"
        Stop-Run 2 "PRECONDITION: backup step failed, nothing was changed: $($_.Exception.Message)"
    }
    if ($script:log.restorePoint.reused) { Write-Output "RESTORE_POINT=reused #$($script:log.restorePoint.sequenceNumber) (Windows allows one new restore point per 24h)" }
    else { Write-Output "RESTORE_POINT=created #$($script:log.restorePoint.sequenceNumber)" }
    Write-Output "REGISTRY_BACKUP=$(@($script:log.registryBackup.files).Count) key(s) -> $($script:log.registryBackup.dir)"
}

function Complete-ApplyRun {
    param([int]$Failures)
    $script:log.outcome = 'completed'
    if ($Failures -gt 0) { $script:log.outcome = 'completed-with-failures' }
    $script:log.finishedAt = (Get-Date).ToString('o')
    Save-Log
    Write-LogSummary -Path $script:logPath
    if ($Failures -gt 0) { Stop-Run 3 '' }
    Stop-Run 0 ''
}

try {
    $Only = Split-List $Only
    $Exclude = Split-List $Exclude
    $badTags = @($Exclude | Where-Object { @('gaming', 'office', 'onedrive', 'edge') -notcontains $_ })
    if ($badTags.Count) { Stop-Run 4 "INVALID: unknown -Exclude tag(s): $($badTags -join ', '). Allowed: gaming, office, onedrive, edge" }
    if ($Auto) {
        if ($DryRun -or $Revert -or $Plan) { Stop-Run 4 'INVALID: -Auto cannot be combined with -DryRun, -Revert or -Plan.' }
        $Apply = $true; $Elevate = $true; $EnableSystemRestore = $true; $AllowUntestedBuild = $true
    }
    if ($DryRun -and $Apply) { Stop-Run 4 'INVALID: -DryRun and -Apply are mutually exclusive.' }
    if ($TargetUserSid) { Set-RegistryTargetSid -Sid $TargetUserSid }

    try { $catalog = Import-DebloatCatalog -Path $CatalogPath }
    catch { Stop-Run 4 "INVALID: $($_.Exception.Message)" }
    $machine = Get-MachineInfo

    $revertPath = $null
    if ($Revert) {
        if (-not (Test-Path -LiteralPath $Revert)) { Stop-Run 4 "INVALID: revert log not found: $Revert" }
        $revertPath = (Resolve-Path -LiteralPath $Revert).Path
    }
    if ($Plan) {
        if (-not (Test-Path -LiteralPath $Plan)) { Stop-Run 4 "INVALID: plan file not found: $Plan" }
        $Plan = (Resolve-Path -LiteralPath $Plan).Path
    }

    $mode = 'DRYRUN'
    if ($Apply) { $mode = 'APPLY' }
    Write-Output "MODE=$mode"
    Write-Output "MACHINE=$($machine.computerName) $($machine.os) build $($machine.build).$($machine.ubr) $($machine.displayVersion) $($machine.edition) admin=$($machine.isAdmin)"
    $tested = @(Get-Prop $catalog 'testedBuilds' @())
    $untested = ($tested.Count -gt 0 -and $tested -notcontains $machine.build)
    if ($untested) {
        Write-Output "WARNING: build $($machine.build) is not in the catalog's testedBuilds ($($tested -join ', ')). Identifiers may differ on this build."
    }
    if ($machine.managed) { Write-Output "WARNING: this machine is managed by an organisation (domain=$($machine.domainJoined) entra=$($machine.entraJoined) mdm=$($machine.mdmEnrolled)). Its policies belong to an administrator." }
    if ($machine.pendingReboot) { Write-Output 'WARNING: a restart is pending (servicing or Windows Update). Restart before applying.' }

    if ($Apply) {
        if ($PSVersionTable.PSEdition -eq 'Core') { Stop-Run 2 'PRECONDITION: -Apply needs Windows PowerShell 5.1 (powershell.exe).' }
        if ($machine.managed) { Stop-Run 2 'PRECONDITION: refusing to change a machine managed by an organisation (domain, Entra or MDM).' }
        if ($machine.pendingReboot) { Stop-Run 2 'PRECONDITION: a restart is pending. Restart Windows, then make a new dry run.' }
        if ($untested -and -not $AllowUntestedBuild) { Stop-Run 2 "PRECONDITION: build $($machine.build) is untested. Re-run with -AllowUntestedBuild only if the user accepts that risk." }
        if (-not $machine.isAdmin) {
            if ($Elevate) { Invoke-ElevatedSelf -RevertPath $revertPath }
            Stop-Run 2 'PRECONDITION: -Apply needs an elevated session. Re-run from an elevated Windows PowerShell, or add -Elevate (a UAC prompt will appear).'
        }
    }

    # ---------------------------------------------------------------- revert
    if ($revertPath) {
        $src = Read-JsonFile -Path $revertPath
        if ((Get-Prop $src 'kind') -ne 'debloat') { Stop-Run 4 'INVALID: -Revert needs a run log written by a debloat -Apply run.' }
        $todo = @(@($src.changes) | Where-Object { $_.status -in 'changed', 'failed' -and $null -ne $_.before })
        [array]::Reverse($todo)
        Write-Output "REVERT_SOURCE=$revertPath"
        Write-Output ('{0,-10} {1,-46} {2}' -f 'ACTION', 'ID', 'FAMILY')
        foreach ($c in $todo) { Write-Output ('{0,-10} {1,-46} {2}' -f 'REVERT', $c.id, $c.family) }
        Write-Output "SUMMARY: $($todo.Count) change(s) to revert"
        if (-not $Apply) {
            Write-Output 'No changes were made. Add -Apply to revert.'
            Stop-Run 0 ''
        }
        Start-ApplyRun -Kind 'revert' -RegistryItems @($todo | ForEach-Object { $_.item }) -Extra @{ sourceLog = $revertPath }
        $failures = 0
        foreach ($c in $todo) {
            $fam = Get-DebloatFamily -Item $c.item
            $rec = [ordered]@{ id = $c.id; family = $c.family; status = ''; detail = ''; at = (Get-Date).ToString('o') }
            try {
                $r = & $fam.Undo -Item $c.item -Before $c.before
                $rec.detail = [string]$r.detail
                if ($r.ok) { $rec.status = 'reverted' }
                elseif ($r.manual) { $rec.status = 'manual-action-required' }
                else { $rec.status = 'failed'; $failures++ }
                if (Get-Prop $r 'restartNeeded') { $script:log.restartRecommended = $true }
            }
            catch { $rec.status = 'failed'; $rec.detail = $_.Exception.Message; $failures++ }
            $script:log.changes += $rec
            Save-Log
        }
        Complete-ApplyRun -Failures $failures
    }

    # ---------------------------------------------------------------- debloat
    $selProfile = $ProfileName; $selOnly = $Only; $selExclude = $Exclude
    $planDoc = $null
    if ($Plan) {
        $planDoc = Read-JsonFile -Path $Plan
        $selProfile = [string]$planDoc.selection.profile
        $selOnly = @(Get-Prop $planDoc.selection 'only' @())
        $selExclude = @(Get-Prop $planDoc.selection 'exclude' @())
        Write-Output "PLAN=$Plan (selection taken from the plan file)"
    }
    try { $selected = @(Select-DebloatItems -Catalog $catalog -ProfileName $selProfile -Only $selOnly -Exclude $selExclude) }
    catch [System.ArgumentException] { Stop-Run 4 "INVALID: $($_.Exception.Message)" }

    Write-Output "SELECTION=profile:$selProfile only:[$($selOnly -join ',')] exclude:[$($selExclude -join ',')]"
    $entries = @($selected | ForEach-Object { Get-DebloatItemStatus -Item $_ -Machine $machine })

    if ($planDoc -and $Apply) {
        # An approved plan is a ceiling: apply never changes an item the plan did not list as CHANGE.
        # (An elevated run can see more than the dry run did, e.g. provisioned packages.)
        $approved = @(@($planDoc.items) | Where-Object { $_.status -eq 'present' } | ForEach-Object { $_.id })
        $expected = Get-PlanHash -CatalogSha ([string]$planDoc.catalogSha256) -Computer ([string]$planDoc.machine.computerName) -Ids $approved
        if ($expected -ne $planDoc.planHash) { Stop-Run 4 'INVALID: plan file does not match its own hash (edited or corrupt). Run a new dry run.' }
        if ($planDoc.catalogSha256 -ne $catalog.sha256 -or $planDoc.machine.computerName -ne $machine.computerName) {
            Stop-Run 2 'PRECONDITION: PLAN_STALE - the catalog changed or the plan is from another machine. Run a new dry run and get it approved.'
        }
        foreach ($e in $entries) {
            if ($e.status -eq 'present' -and $approved -notcontains $e.id) {
                $e.status = 'not-in-plan'
                $e.detail = "$($e.detail) [not in the approved plan; run a new dry run to include it]"
            }
        }
    }
    $toChange = @($entries | Where-Object { $_.status -eq 'present' })
    $planHash = Get-PlanHash -CatalogSha $catalog.sha256 -Computer $machine.computerName -Ids @($toChange | ForEach-Object { $_.id })

    Write-PlanTable -Entries $entries
    foreach ($e in @($toChange | Where-Object { $_.tier -eq 'never-default' })) {
        Write-Output "WARNING: '$($e.id)' is tier never-default and was selected explicitly with -Only."
    }
    $counts = @($entries | Group-Object status | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '
    Write-Output "SUMMARY: selected=$($entries.Count) to-change=$($toChange.Count) [$counts]"
    Write-Output "PLAN_HASH=$planHash"

    if (-not $Apply) {
        $planPath = Join-Path $LogDir "plan-$RunId.json"
        Save-JsonFile -Path $planPath -Object ([ordered]@{
                schema = 1; runId = $RunId; createdAt = (Get-Date).ToString('o'); machine = $machine
                selection = [ordered]@{ profile = $selProfile; only = @($selOnly); exclude = @($selExclude) }
                catalogSha256 = $catalog.sha256; planHash = $planHash
                items = @($entries | ForEach-Object {
                        [ordered]@{ id = $_.id; name = $_.name; category = $_.category; tier = $_.tier; op = $_.op
                            status = $_.status; action = (Get-ActionLabel $_.status); detail = $_.detail; target = $_.item.target }
                    })
            })
        Write-Output "PLAN_FILE=$planPath"
        Write-Output 'No changes were made. To apply exactly this plan: -Apply -Plan <PLAN_FILE>'
        Stop-Run 0 ''
    }

    if ($toChange.Count -eq 0) {
        Write-Output 'Nothing to change.'
        Stop-Run 0 ''
    }

    Start-ApplyRun -Kind 'debloat' -RegistryItems @($toChange | ForEach-Object { $_.item }) -Extra @{
        selection = [ordered]@{ profile = $selProfile; only = @($selOnly); exclude = @($selExclude) }
        planFile = $Plan; planHash = $planHash
    }
    $failures = 0
    foreach ($e in $entries) {
        $rec = [ordered]@{
            id = $e.id; name = $e.name; family = $e.family; op = $e.op; status = ''; detail = $e.detail; before = $null; verified = $null
            item = [ordered]@{ id = $e.item.id; target = $e.item.target; detect = $e.item.detect; remove = $e.item.remove; revert = $e.item.revert; builds = $e.item.builds }
            at = (Get-Date).ToString('o')
        }
        if ($e.status -ne 'present') { $rec.status = "skipped-$($e.status)" }
        else {
            $fam = Get-DebloatFamily -Item $e.item
            $rec.before = $e.state.current
            try {
                $r = & $fam.Remove -Item $e.item -State $e.state
                $rec.status = 'changed'; $rec.detail = [string]$r.detail
                if (Get-Prop $r 'restartNeeded') { $script:log.restartRecommended = $true }
                $after = Get-DebloatItemStatus -Item $e.item -Machine $machine
                $rec.verified = ($after.status -in 'applied', 'not-present')
            }
            catch { $rec.status = 'failed'; $rec.detail = $_.Exception.Message; $failures++ }
        }
        $script:log.changes += $rec
        Save-Log
    }
    Complete-ApplyRun -Failures $failures
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    Write-Output $_.ScriptStackTrace
    Write-Output 'EXIT_CODE=1'
    exit 1
}
