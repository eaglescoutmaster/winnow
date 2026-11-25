# Pester 5. Runs Invoke-Debloat.ps1 and Test-State.ps1 in child processes, the way an agent would.
# Nothing here passes -Apply from an elevated session, so no test can change the machine.

BeforeAll {
    $script:root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:root 'scripts\modules\Common.psm1') -Force -Global -DisableNameChecking
    $script:entry = Join-Path $script:root 'scripts\Invoke-Debloat.ps1'
    $script:state = Join-Path $script:root 'scripts\Test-State.ps1'
    $script:fixture = Join-Path $PSScriptRoot 'fixtures\catalog.json'
    $script:logDir = Join-Path $TestDrive 'logs'
    $script:isAdmin = Test-IsAdmin

    function Invoke-Entry {
        param([string]$Script = $script:entry, [string[]]$ArgList = @(), [switch]$RealCatalog)
        $a = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $Script) + $ArgList
        if ($Script -eq $script:entry) { $a += @('-LogDir', $script:logDir) }
        if (-not $RealCatalog) { $a += @('-CatalogPath', $script:fixture) }
        # A child that writes to stderr must not become a terminating error in the test host.
        $ErrorActionPreference = 'Continue'
        $out = & powershell.exe @a 2>&1 | ForEach-Object { "$_" }
        [pscustomobject]@{ Code = $LASTEXITCODE; Out = @($out); Text = ($out -join "`n") }
    }
    function Get-PlanFromOutput {
        param($Result)
        $line = $Result.Out | Where-Object { $_ -like 'PLAN_FILE=*' } | Select-Object -First 1
        Read-JsonFile -Path ($line -replace '^PLAN_FILE=', '')
    }
}

Describe 'Invoke-Debloat.ps1 dry run' {
    It 'is the default mode, exits 0, writes a plan and no run log' {
        $r = Invoke-Entry
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'MODE=DRYRUN'
        $r.Text | Should -Match 'No changes were made'
        $plan = Get-PlanFromOutput $r
        $plan.planHash | Should -Match '^[0-9A-F]{64}$'
        @(Get-ChildItem -LiteralPath $script:logDir -Filter 'run-*.json').Count | Should -Be 0
    }

    It 'never plans never-default items for profile <_>' -ForEach 'safe', 'moderate', 'aggressive' {
        $r = Invoke-Entry -ArgList '-Profile', $_
        $r.Code | Should -Be 0
        @((Get-PlanFromOutput $r).items | Where-Object { $_.tier -eq 'never-default' }).Count | Should -Be 0
    }

    It 'widens the selection with the profile' {
        $safe = @((Get-PlanFromOutput (Invoke-Entry -ArgList '-Profile', 'safe')).items).Count
        $aggr = @((Get-PlanFromOutput (Invoke-Entry -ArgList '-Profile', 'aggressive')).items).Count
        $aggr | Should -BeGreaterThan $safe
    }

    It 'includes a never-default item only when named with -Only' {
        $r = Invoke-Entry -ArgList '-Only', 'fx-never-default,fx-reg-safe'
        $r.Code | Should -Be 0
        $ids = @((Get-PlanFromOutput $r).items | ForEach-Object { $_.id })
        $ids | Should -Contain 'fx-never-default'
        $ids.Count | Should -Be 2
    }

    It 'honours -Exclude' {
        $r = Invoke-Entry -ArgList '-Profile', 'aggressive', '-Exclude', 'gaming'
        @((Get-PlanFromOutput $r).items | ForEach-Object { $_.id }) | Should -Not -Contain 'fx-gaming-safe'
    }

    It 'marks items for other builds as skip:n/a' {
        $r = Invoke-Entry
        ((Get-PlanFromOutput $r).items | Where-Object { $_.id -eq 'fx-future-build' }).action | Should -Be 'skip:n/a'
    }

    It 'runs against the real catalog' {
        $r = Invoke-Entry -RealCatalog -ArgList '-Profile', 'aggressive'
        $r.Code | Should -Be 0 -Because $r.Text
        $r.Text | Should -Match 'PLAN_FILE='
    }
}

Describe 'Invoke-Debloat.ps1 input and precondition handling' {
    It 'exits 4 for an unknown -Only id' {
        (Invoke-Entry -ArgList '-Only', 'no-such-item').Code | Should -Be 4
    }
    It 'exits 4 for an unknown -Exclude tag' {
        (Invoke-Entry -ArgList '-Exclude', 'printers').Code | Should -Be 4
    }
    It 'exits 4 when -Auto is combined with -DryRun' {
        (Invoke-Entry -ArgList '-Auto', '-DryRun').Code | Should -Be 4
    }

    It 'defaults to the aggressive profile' {
        (Invoke-Entry).Text | Should -Match 'SELECTION=profile:aggressive'
    }

    It 'exits 4 when -DryRun and -Apply are combined' {
        (Invoke-Entry -ArgList '-DryRun', '-Apply').Code | Should -Be 4
    }
    It 'exits 4 for a missing plan or revert file' {
        (Invoke-Entry -ArgList '-Plan', 'C:\no\such\plan.json').Code | Should -Be 4
        (Invoke-Entry -ArgList '-Revert', 'C:\no\such\run.json').Code | Should -Be 4
    }
    It 'exits 4 for an invalid catalog' {
        $bad = Join-Path $TestDrive 'bad.json'
        '{ "schemaVersion": 1, "items": [] }' | Set-Content -LiteralPath $bad -Encoding ASCII
        $r = Invoke-Entry -RealCatalog -ArgList '-CatalogPath', $bad
        $r.Code | Should -Be 4
    }
    It 'rejects a profile outside the closed set' {
        (Invoke-Entry -ArgList '-Profile', 'everything').Code | Should -Not -Be 0
    }
    It 'refuses -Apply without elevation (exit 2) and changes nothing' -Skip:$script:isAdmin {
        $r = Invoke-Entry -ArgList '-Apply', '-Only', 'fx-reg-safe'
        $r.Code | Should -Be 2
        $r.Text | Should -Match 'PRECONDITION'
        Test-Path -LiteralPath 'HKCU:\Software\WinDebloatKitTest\Fixture' | Should -BeFalse
    }
}

Describe 'Invoke-Debloat.ps1 -Revert dry run' {
    It 'lists logged changes in reverse order and changes nothing' {
        $fx = Read-JsonFile -Path $script:fixture
        $mk = {
            param($id)
            $it = $fx.items | Where-Object { $_.id -eq $id }
            [ordered]@{ id = $id; family = 'x'; status = 'changed'; before = @{ exists = $false; keyExists = $false }
                item = [ordered]@{ id = $id; target = $it.target; detect = $it.detect; remove = $it.remove; revert = $it.revert } }
        }
        $log = Join-Path $TestDrive 'run-sample.json'
        Save-JsonFile -Path $log -Object ([ordered]@{ schema = 1; kind = 'debloat'; changes = @((& $mk 'fx-reg-safe'), (& $mk 'fx-future-build')) })
        $r = Invoke-Entry -ArgList '-Revert', $log
        $r.Code | Should -Be 0
        $lines = @($r.Out | Where-Object { $_ -match '^REVERT ' })
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match 'fx-future-build'
        $r.Text | Should -Match 'No changes were made'
    }
    It 'rejects a file that is not a debloat run log' {
        $log = Join-Path $TestDrive 'not-a-log.json'
        '{ "kind": "revert", "changes": [] }' | Set-Content -LiteralPath $log -Encoding ASCII
        (Invoke-Entry -ArgList '-Revert', $log).Code | Should -Be 4
    }
}

Describe 'Test-State.ps1' {
    It 'emits valid JSON covering every catalog item' {
        $r = Invoke-Entry -Script $script:state -ArgList '-AsJson'
        $r.Code | Should -Be 0
        $doc = $r.Text | ConvertFrom-Json
        @($doc.items).Count | Should -Be @((Read-JsonFile -Path $script:fixture).items).Count
        $doc.machine.build | Should -BeGreaterThan 0
    }
    It 'prints a text report for the real catalog' {
        $r = Invoke-Entry -Script $script:state -RealCatalog
        $r.Code | Should -Be 0 -Because $r.Text
        $r.Text | Should -Match 'STATUS_COUNTS:'
    }
}
