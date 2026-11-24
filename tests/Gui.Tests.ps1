# Pester 5. Starts scripts\Start-Gui.ps1 against the fixture catalog and talks to it over
# loopback. Read-only calls only: no test here applies anything.

BeforeAll {
    $script:root = Split-Path -Parent $PSScriptRoot
    $script:logDir = Join-Path $TestDrive 'logs'
    $script:outFile = Join-Path $TestDrive 'gui-out.txt'
    $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $script:port = $probe.LocalEndpoint.Port; $probe.Stop()
    $a = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $script:root 'scripts\Start-Gui.ps1'),
        '-NoBrowser', '-Port', $script:port, '-CatalogPath', (Join-Path $PSScriptRoot 'fixtures\catalog.json'), '-LogDir', $script:logDir)
    $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $a -RedirectStandardOutput $script:outFile -WindowStyle Hidden -PassThru
    $script:token = $null
    foreach ($i in 1..60) {
        Start-Sleep -Milliseconds 500
        $line = Get-Content -LiteralPath $script:outFile -ErrorAction SilentlyContinue | Where-Object { $_ -like 'WINNOW_GUI_URL=*' } | Select-Object -First 1
        if ($line) { $script:token = ($line -replace '^.*\?t=', '').Trim(); break }
    }
    $script:base = "http://localhost:$($script:port)"

    function Invoke-Gui {
        param([string]$Path, $Body, [string]$Token = $script:token, [hashtable]$Headers = @{})
        $h = @{ 'X-Winnow-Token' = $Token } + $Headers
        $p = @{ Uri = "$($script:base)$Path"; Headers = $h; UseBasicParsing = $true; TimeoutSec = 120 }
        if ($null -ne $Body) { $p.Method = 'Post'; $p.Body = ($Body | ConvertTo-Json -Compress -Depth 5); $p.ContentType = 'application/json' }
        try { $r = Invoke-WebRequest @p; return [pscustomobject]@{ Code = [int]$r.StatusCode; Text = $r.Content } }
        catch {
            $res = $_.Exception.Response
            if (-not $res) { throw }
            return [pscustomobject]@{ Code = [int]$res.StatusCode; Text = '' }
        }
    }
}

AfterAll {
    try { Invoke-Gui -Path '/api/quit' -Body @{ } | Out-Null } catch { }
    if ($script:proc -and -not $script:proc.WaitForExit(5000)) { $script:proc | Stop-Process -Force -ErrorAction SilentlyContinue }
}

Describe 'Start-Gui.ps1' {
    It 'starts and prints its URL with a token' {
        $script:token | Should -Match '^[0-9a-f]{48}$'
    }
    It 'serves the page only with the token in the URL' {
        (Invoke-Gui -Path '/').Code | Should -Be 403
        $r = Invoke-Gui -Path "/?t=$($script:token)"
        $r.Code | Should -Be 200
        $r.Text | Should -Match '<title>Winnow</title>'
    }
    It 'rejects API calls without the token or from another origin' {
        (Invoke-Gui -Path '/api/state' -Token 'nope').Code | Should -Be 403
        (Invoke-Gui -Path '/api/state' -Headers @{ Origin = 'http://evil.test' }).Code | Should -Be 403
        (Invoke-Gui -Path '/api/plan' -Token 'nope' -Body @{ only = @('fx-reg-safe') }).Code | Should -Be 403
    }
    It 'reports state merged with catalog details' {
        $r = Invoke-Gui -Path '/api/state'
        $r.Code | Should -Be 200
        $doc = $r.Text | ConvertFrom-Json
        $doc.platform | Should -Be 'windows'
        @($doc.items).Count | Should -Be @((Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures\catalog.json') | ConvertFrom-Json).items).Count
        $doc.items[0].PSObject.Properties.Name | Should -Contain 'notes'
        @($doc.options | ForEach-Object { $_.key }) | Should -Contain 'allowUntestedBuild'
    }
    It 'builds a dry-run plan and writes no run log' {
        $r = Invoke-Gui -Path '/api/plan' -Body @{ only = @('fx-reg-safe') }
        $r.Code | Should -Be 200
        $doc = $r.Text | ConvertFrom-Json
        $doc.exitCode | Should -Be 0
        $doc.planFile | Should -Match '^plan-[0-9a-z-]+\.json$'
        @($doc.plan.items | ForEach-Object { $_.id }) | Should -Be @('fx-reg-safe')
        @(Get-ChildItem -LiteralPath $script:logDir -Filter 'run-*.json').Count | Should -Be 0
        Test-Path -LiteralPath 'HKCU:\Software\WinDebloatKitTest\Fixture' | Should -BeFalse
    }
    It 'rejects bad ids and files outside its log folder' {
        (Invoke-Gui -Path '/api/plan' -Body @{ only = @('a;calc') }).Code | Should -Be 400
        (Invoke-Gui -Path '/api/plan' -Body @{ only = @() }).Code | Should -Be 400
        (Invoke-Gui -Path '/api/apply' -Body @{ planFile = '../../catalog/items.json' }).Code | Should -Be 400
        (Invoke-Gui -Path '/api/apply' -Body @{ planFile = 'plan-missing.json' }).Code | Should -Be 400
        (Invoke-Gui -Path '/api/revert' -Body @{ logFile = 'plan-x.json'; apply = $true }).Code | Should -Be 400
    }
    It 'lists runs as an array' {
        (Invoke-Gui -Path '/api/runs').Text | Should -Be '[]'
    }
}
