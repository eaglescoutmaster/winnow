# Pester 5. Catalog schema and policy tests. Read-only.

BeforeAll {
    $script:root = Split-Path -Parent $PSScriptRoot
    Get-ChildItem -LiteralPath (Join-Path $script:root 'scripts\modules') -Filter *.psm1 |
        ForEach-Object { Import-Module $_.FullName -Force -Global -DisableNameChecking }
    $script:catalogPath = Join-Path $script:root 'catalog\items.json'
    $script:schemaPath = Join-Path $script:root 'catalog\items.schema.json'
    $script:catalog = Read-JsonFile -Path $script:catalogPath
    $script:fixturePath = Join-Path $PSScriptRoot 'fixtures\catalog.json'
}

Describe 'catalog/items.json' {
    It 'passes the built-in validator' {
        @(Test-DebloatCatalog -Catalog $script:catalog) | Should -BeNullOrEmpty
    }

    It 'validates against items.schema.json (needs Test-Json, PowerShell 6+)' -Skip:(-not (Get-Command Test-Json -ErrorAction SilentlyContinue)) {
        Test-Json -Json (Get-Content -LiteralPath $script:catalogPath -Raw) -SchemaFile $script:schemaPath | Should -BeTrue
    }

    It 'has unique ids' {
        $ids = @($script:catalog.items | ForEach-Object { $_.id })
        @($ids | Select-Object -Unique).Count | Should -Be $ids.Count
    }

    It 'gives every item at least one https source' {
        foreach ($it in $script:catalog.items) {
            @($it.sources).Count | Should -BeGreaterThan 0 -Because $it.id
            foreach ($s in $it.sources) { $s | Should -Match '^https://' -Because $it.id }
        }
    }

    It 'never selects never-default items through a profile' {
        foreach ($p in 'safe', 'moderate', 'aggressive') {
            $sel = @(Select-DebloatItems -Catalog $script:catalog -ProfileName $p)
            @($sel | Where-Object { $_.tier -eq 'never-default' }).Count | Should -Be 0 -Because "profile $p"
        }
    }

    It 'makes profiles cumulative' {
        $safe = @(Select-DebloatItems -Catalog $script:catalog -ProfileName safe | ForEach-Object { $_.id })
        $moderate = @(Select-DebloatItems -Catalog $script:catalog -ProfileName moderate | ForEach-Object { $_.id })
        $aggressive = @(Select-DebloatItems -Catalog $script:catalog -ProfileName aggressive | ForEach-Object { $_.id })
        @($safe | Where-Object { $moderate -notcontains $_ }).Count | Should -Be 0
        @($moderate | Where-Object { $aggressive -notcontains $_ }).Count | Should -Be 0
    }

    It 'keeps protected identifiers out of every profile' {
        $sel = @(Select-DebloatItems -Catalog $script:catalog -ProfileName aggressive)
        foreach ($it in $sel) {
            Test-ProtectedTarget -Item $it -Protected $script:catalog.protected | Should -BeFalse -Because $it.id
        }
    }

    It 'is the only place identifiers live (scripts hold no removal lists)' {
        $code = (Get-ChildItem -LiteralPath (Join-Path $script:root 'scripts') -Recurse -File -Include *.ps1, *.psm1 |
                ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
        foreach ($it in $script:catalog.items) {
            foreach ($field in 'packageName', 'taskName', 'featureName') {
                $v = Get-Prop $it.target $field
                if ($v) { $code.Contains($v) | Should -BeFalse -Because "$v is hardcoded in scripts" }
            }
        }
    }
}

Describe 'Test-DebloatCatalog' {
    BeforeEach { $script:fx = Read-JsonFile -Path $script:fixturePath }

    It 'accepts the fixture catalog' {
        @(Test-DebloatCatalog -Catalog $script:fx) | Should -BeNullOrEmpty
    }
    It 'rejects a duplicate id' {
        $script:fx.items[1].id = $script:fx.items[0].id
        (@(Test-DebloatCatalog -Catalog $script:fx) -join ';') | Should -Match 'duplicate id'
    }
    It 'rejects an item without sources' {
        $script:fx.items[0].sources = @()
        (@(Test-DebloatCatalog -Catalog $script:fx) -join ';') | Should -Match 'at least one source'
    }
    It 'rejects an unknown operation' {
        $script:fx.items[0].remove.op = 'run-command'
        (@(Test-DebloatCatalog -Catalog $script:fx) -join ';') | Should -Match 'unknown remove.op'
    }
    It 'rejects a protected target outside tier never-default' {
        ($script:fx.items | Where-Object { $_.id -eq 'fx-never-default' }).tier = 'safe'
        (@(Test-DebloatCatalog -Catalog $script:fx) -join ';') | Should -Match 'protected identifier'
    }
    It 'rejects a policy-set outside a Policies key' {
        ($script:fx.items | Where-Object { $_.id -eq 'fx-future-build' }).target.path = 'SOFTWARE\Microsoft\Windows'
        (@(Test-DebloatCatalog -Catalog $script:fx) -join ';') | Should -Match 'Policies key'
    }
    It 'rejects mismatched detect and remove values' {
        $script:fx.items[0].remove.value = 5
        (@(Test-DebloatCatalog -Catalog $script:fx) -join ';') | Should -Match 'differs from detect.value'
    }
}
