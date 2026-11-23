# Pester 5. Real change/revert of services and scheduled tasks, plus the "stop if the backup
# fails" path of -Apply. These tests create and delete their own throwaway service and task.
# They run only when BOTH are true: the session is elevated and WINNOW_ELEVATED_TESTS=1 is set
# (the CI workflow sets it). They never touch catalog items.

BeforeDiscovery {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $script:skipElevated = -not ($admin -and $env:WINNOW_ELEVATED_TESTS -eq '1')
}

BeforeAll {
    $script:root = Split-Path -Parent $PSScriptRoot
    Get-ChildItem -LiteralPath (Join-Path $script:root 'scripts\modules') -Filter *.psm1 |
        ForEach-Object { Import-Module $_.FullName -Force -Global -DisableNameChecking }
    $script:svcName = 'WinnowTestSvc'
    $script:taskPath = '\WinnowTest\'
    $script:taskName = 'WinnowTestTask'
}

Describe 'Services module against a throwaway service' -Skip:$script:skipElevated {
    BeforeAll {
        New-Service -Name $script:svcName -BinaryPathName "$env:SystemRoot\System32\svchost.exe -k WinnowTest" -StartupType Manual | Out-Null
        $script:svcItem = [pscustomobject]@{
            id = 't-svc'; target = [pscustomobject]@{ name = $script:svcName }
            detect = [pscustomobject]@{ op = 'service-startup'; startup = 'Disabled' }
            remove = [pscustomobject]@{ op = 'service-disable' }
            revert = [pscustomobject]@{ op = 'service-restore'; defaultStartup = 'Manual' }
        }
    }
    AfterAll { & "$env:SystemRoot\System32\sc.exe" delete $script:svcName | Out-Null }

    It 'disables the service and restores its logged start type' {
        $before = Get-ServiceItemState -Item $script:svcItem
        $before.present | Should -BeTrue
        $before.applied | Should -BeFalse
        $before.current.startup | Should -Be 'Manual'

        Invoke-ServiceItemRemove -Item $script:svcItem -State $before | Out-Null
        (Get-ServiceItemState -Item $script:svcItem).applied | Should -BeTrue

        $logged = $before.current | ConvertTo-Json | ConvertFrom-Json
        (Invoke-ServiceItemRevert -Item $script:svcItem -Before $logged).ok | Should -BeTrue
        (Get-ServiceItemState -Item $script:svcItem).current.startup | Should -Be 'Manual'
    }
}

Describe 'Tasks module against a throwaway task' -Skip:$script:skipElevated {
    BeforeAll {
        $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\cmd.exe" -Argument '/c exit 0'
        Register-ScheduledTask -TaskPath $script:taskPath -TaskName $script:taskName -Action $action -User 'SYSTEM' | Out-Null
        $script:taskItem = [pscustomobject]@{
            id = 't-task'; target = [pscustomobject]@{ taskPath = $script:taskPath; taskName = $script:taskName }
            detect = [pscustomobject]@{ op = 'task-disabled' }
            remove = [pscustomobject]@{ op = 'task-disable' }
            revert = [pscustomobject]@{ op = 'task-enable' }
        }
    }
    AfterAll { Unregister-ScheduledTask -TaskPath $script:taskPath -TaskName $script:taskName -Confirm:$false -ErrorAction SilentlyContinue }

    It 'disables the task and re-enables it on revert' {
        $before = Get-TaskItemState -Item $script:taskItem
        $before.present | Should -BeTrue
        $before.applied | Should -BeFalse

        Invoke-TaskItemRemove -Item $script:taskItem -State $before | Out-Null
        (Get-TaskItemState -Item $script:taskItem).applied | Should -BeTrue

        $logged = $before.current | ConvertTo-Json | ConvertFrom-Json
        (Invoke-TaskItemRevert -Item $script:taskItem -Before $logged).ok | Should -BeTrue
        (Get-TaskItemState -Item $script:taskItem).applied | Should -BeFalse
    }
}

Describe 'Invoke-Debloat.ps1 -Apply, elevated, fixture catalog' -Skip:$script:skipElevated {
    # Outcome depends on the host: where System Restore works the run completes and is reverted;
    # where it does not (Windows Server runners) the run must abort before any change.
    It 'either completes and reverts cleanly, or aborts with nothing changed' {
        $logDir = Join-Path $TestDrive 'logs'
        $entry = Join-Path $script:root 'scripts\Invoke-Debloat.ps1'
        $fixture = Join-Path $PSScriptRoot 'fixtures\catalog.json'
        $key = 'HKCU:\Software\WinDebloatKitTest\Fixture'
        Remove-Item -LiteralPath 'HKCU:\Software\WinDebloatKitTest' -Recurse -Force -ErrorAction SilentlyContinue
        $common = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $entry, '-CatalogPath', $fixture, '-LogDir', $logDir, '-AllowUntestedBuild')

        $out = & powershell.exe @common -Apply -Only fx-reg-safe 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
        $log = Get-ChildItem -LiteralPath $logDir -Filter 'run-*.json' -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($code -eq 2) {
            # Precondition stop: managed host, pending restart, or no restore point. Nothing may have changed.
            ($out -join "`n") | Should -Match 'PRECONDITION'
            if ($log) { (Read-JsonFile -Path $log.FullName).outcome | Should -Be 'aborted' }
            Test-Path -LiteralPath $key | Should -BeFalse
        }
        else {
            $code | Should -Be 0 -Because ($out -join "`n")
            $log | Should -Not -BeNullOrEmpty
            $doc = Read-JsonFile -Path $log.FullName
            $doc.outcome | Should -Be 'completed'
            (Get-ItemProperty -LiteralPath $key).SafeValue | Should -Be 0
            & powershell.exe @common -Revert $log.FullName -Apply 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
            Test-Path -LiteralPath $key | Should -BeFalse
        }
        Remove-Item -LiteralPath 'HKCU:\Software\WinDebloatKitTest' -Recurse -Force -ErrorAction SilentlyContinue
    }
}
