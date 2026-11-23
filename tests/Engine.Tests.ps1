# Pester 5. In-process engine tests. The registry round trip writes only under
# HKCU\Software\WinDebloatKitTest and removes that key afterwards.

BeforeAll {
    $script:root = Split-Path -Parent $PSScriptRoot
    Get-ChildItem -LiteralPath (Join-Path $script:root 'scripts\modules') -Filter *.psm1 |
        ForEach-Object { Import-Module $_.FullName -Force -Global -DisableNameChecking }
    $script:fx = Read-JsonFile -Path (Join-Path $PSScriptRoot 'fixtures\catalog.json')
    $script:machine = Get-MachineInfo
    $script:testKey = 'HKCU:\Software\WinDebloatKitTest'
}

AfterAll {
    Remove-Item -LiteralPath $script:testKey -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Select-DebloatItems' {
    It 'selects only safe items for the safe profile' {
        $ids = @(Select-DebloatItems -Catalog $script:fx -ProfileName safe | ForEach-Object { $_.id })
        $ids | Should -Contain 'fx-reg-safe'
        $ids | Should -Not -Contain 'fx-service-moderate'
        $ids | Should -Not -Contain 'fx-never-default'
    }
    It 'drops items whose tag is excluded' {
        $ids = @(Select-DebloatItems -Catalog $script:fx -ProfileName aggressive -Exclude gaming | ForEach-Object { $_.id })
        $ids | Should -Not -Contain 'fx-gaming-safe'
        $ids | Should -Contain 'fx-task-aggressive'
    }
    It 'returns exactly the named items for -Only, including never-default' {
        $ids = @(Select-DebloatItems -Catalog $script:fx -ProfileName safe -Only 'fx-never-default' | ForEach-Object { $_.id })
        $ids | Should -Be @('fx-never-default')
    }
    It 'throws on an unknown id' {
        { Select-DebloatItems -Catalog $script:fx -Only 'nope' } | Should -Throw '*Unknown item id*'
    }
}

Describe 'Get-DebloatItemStatus' {
    It 'reports <id> as <expected>' -ForEach @(
        @{ id = 'fx-appx-safe'; expected = 'not-present' }
        @{ id = 'fx-service-moderate'; expected = 'not-present' }
        @{ id = 'fx-task-aggressive'; expected = 'not-present' }
        @{ id = 'fx-future-build'; expected = 'not-applicable' }
    ) {
        $item = $script:fx.items | Where-Object { $_.id -eq $id }
        (Get-DebloatItemStatus -Item $item -Machine $script:machine).status | Should -Be $expected
    }
}

Describe 'Registry round trip' {
    BeforeEach {
        Remove-Item -LiteralPath $script:testKey -Recurse -Force -ErrorAction SilentlyContinue
        $script:item = $script:fx.items | Where-Object { $_.id -eq 'fx-reg-safe' }
    }

    It 'sets a missing value, detects it, and revert removes value and created key' {
        $before = Get-DebloatItemStatus -Item $script:item -Machine $script:machine
        $before.status | Should -Be 'present'
        $before.state.current.exists | Should -BeFalse

        Invoke-RegistryItemRemove -Item $script:item -State $before.state | Out-Null
        (Get-DebloatItemStatus -Item $script:item -Machine $script:machine).status | Should -Be 'applied'
        (Get-ItemProperty -LiteralPath "$($script:testKey)\Fixture").SafeValue | Should -Be 0

        (Invoke-RegistryItemRevert -Item $script:item -Before $before.state.current).ok | Should -BeTrue
        Test-Path -LiteralPath "$($script:testKey)\Fixture" | Should -BeFalse
    }

    It 'restores a pre-existing value, including after a JSON round trip of the log' {
        New-Item -Path "$($script:testKey)\Fixture" -Force | Out-Null
        Set-ItemProperty -LiteralPath "$($script:testKey)\Fixture" -Name SafeValue -Value 7 -Type DWord
        $before = Get-DebloatItemStatus -Item $script:item -Machine $script:machine
        $before.status | Should -Be 'present'

        Invoke-RegistryItemRemove -Item $script:item -State $before.state | Out-Null
        (Get-ItemProperty -LiteralPath "$($script:testKey)\Fixture").SafeValue | Should -Be 0

        $logged = $before.state.current | ConvertTo-Json | ConvertFrom-Json
        Invoke-RegistryItemRevert -Item $script:item -Before $logged | Out-Null
        (Get-ItemProperty -LiteralPath "$($script:testKey)\Fixture").SafeValue | Should -Be 7
    }

    It 'is idempotent: an applied item is not reported as a change' {
        $s = Get-DebloatItemStatus -Item $script:item -Machine $script:machine
        Invoke-RegistryItemRemove -Item $script:item -State $s.state | Out-Null
        (Get-DebloatItemStatus -Item $script:item -Machine $script:machine).status | Should -Be 'applied'
    }
}

Describe 'Policies guard' {
    It 'refuses a policy item whose path is not a policy key' {
        $bad = [pscustomobject]@{ id = 'x'; target = [pscustomobject]@{ hive = 'HKCU'; path = 'Software\WinDebloatKitTest'; name = 'v' } }
        { Get-PolicyItemState -Item $bad } | Should -Throw '*not a policy path*'
    }
}

Describe 'Get-PlanHash' {
    It 'is independent of id order and sensitive to content' {
        $a = Get-PlanHash -CatalogSha 'abc' -Computer 'PC' -Ids 'b', 'a'
        $b = Get-PlanHash -CatalogSha 'abc' -Computer 'PC' -Ids 'a', 'b'
        $c = Get-PlanHash -CatalogSha 'abc' -Computer 'PC' -Ids 'a'
        $a | Should -Be $b
        $a | Should -Not -Be $c
    }
}
