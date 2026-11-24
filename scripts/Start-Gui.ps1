<#
.SYNOPSIS
Winnow GUI for Windows: a local web page in front of Test-State.ps1 and Invoke-Debloat.ps1.

.DESCRIPTION
Listens on localhost only and needs the one-time token in its URL for every request. It does
nothing the command line cannot: it runs the two engine scripts and shows their results.
Applying a plan raises the normal Windows elevation prompt.

.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Start-Gui.ps1
#>
[CmdletBinding()]
param(
    [int]$Port = 0,
    [switch]$NoBrowser,
    [string]$CatalogPath,
    [string]$LogDir
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $CatalogPath) { $CatalogPath = Join-Path $root 'catalog\items.json' }
if (-not $LogDir) { $LogDir = Join-Path $root 'logs' }
$entry = Join-Path $PSScriptRoot 'Invoke-Debloat.ps1'
$stateScript = Join-Path $PSScriptRoot 'Test-State.ps1'
$page = Join-Path $root 'gui\index.html'
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-Field {
    param($Object, [string]$Name, $Default = $null)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}

function Invoke-Engine {
    # Runs one engine script in a child process; returns exit code and combined output.
    param([string]$Script, [string[]]$ArgList = @())
    $a = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-CatalogPath', $CatalogPath) + $ArgList
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = & $psExe @a 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $old }
    return @{ exitCode = $LASTEXITCODE; output = (@($out) -join "`n") }
}

function Resolve-LogFile {
    # Only files this tool wrote, inside the log directory.
    param([string]$Name, [string]$Prefix)
    $base = [IO.Path]::GetFileName([string]$Name)
    if ($base -notmatch "^$Prefix-[0-9A-Za-z-]+\.json$") { throw [ArgumentException]"not a $Prefix file" }
    $path = Join-Path $LogDir $base
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw [ArgumentException]"$Prefix file not found" }
    return $path
}

function Read-Json { param([string]$Path) return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json) }

function Get-OutputField {
    param([string]$Output, [string]$Name)
    $m = [regex]::Match($Output, "(?m)^$Name=(.+)$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Get-GuiState {
    $r = Invoke-Engine -Script $stateScript -ArgList @('-AsJson')
    if ($r.exitCode -ne 0) { throw $r.output }
    $doc = $r.output.Substring($r.output.IndexOf('{')) | ConvertFrom-Json
    $cat = Read-Json $CatalogPath
    $byId = @{}
    foreach ($i in $cat.items) { $byId[$i.id] = $i }
    $tags = New-Object System.Collections.Generic.List[string]
    $items = foreach ($s in $doc.items) {
        $c = $byId[$s.id]
        foreach ($t in @(Get-Field $c 'tags' @())) { if (-not $tags.Contains($t)) { $tags.Add($t) } }
        [ordered]@{
            id = $s.id; name = $s.name; category = $s.category; tier = $s.tier; status = $s.status; detail = $s.detail
            tags = @(Get-Field $c 'tags' @()); notes = [string](Get-Field $c 'notes' '')
            sources = @(Get-Field $c 'sources' @()); returns = [string](Get-Field $c 'returnsAfterFeatureUpdate' 'unknown')
        }
    }
    $m = $doc.machine
    $warnings = New-Object System.Collections.Generic.List[string]
    if (@($doc.testedBuilds) -notcontains $m.build) {
        $warnings.Add("Windows build $($m.build) is not one the catalog was written for ($(@($doc.testedBuilds) -join ', ')). Applying needs the 'untested build' option.")
    }
    if ($m.managed) { $warnings.Add('This machine is managed by an organisation (domain, Entra or MDM). Winnow will not change it.') }
    if ($m.pendingReboot) { $warnings.Add('A restart is pending. Restart Windows before applying.') }
    if (-not $m.isAdmin) { $warnings.Add('Not elevated: apps installed for other users are not visible until a plan is applied.') }
    return [ordered]@{
        platform = 'windows'
        machine  = [ordered]@{ summary = "$($m.computerName) | $($m.os) build $($m.build).$($m.ubr) $($m.displayVersion)"; build = $m.build; isAdmin = $m.isAdmin }
        warnings = @($warnings)
        tags     = @($tags | Sort-Object)
        options  = @(
            [ordered]@{ key = 'enableSystemRestore'; label = 'Turn on System Restore for the system drive first'; help = 'Needed when no restore point can be created (System Restore is off by default on Windows 11).' },
            [ordered]@{ key = 'allowUntestedBuild'; label = 'Allow a Windows build the catalog was not written for'; help = 'Identifiers may differ on this build. Read the plan carefully.' }
        )
        items    = @($items)
    }
}

function New-GuiPlan {
    param($Body)
    $only = @(Get-Field $Body 'only' @() | ForEach-Object { [string]$_ })
    if ($only.Count -eq 0 -or @($only | Where-Object { $_ -notmatch '^[a-z0-9-]+$' }).Count -gt 0) { throw [ArgumentException]'only must be a list of item ids' }
    $r = Invoke-Engine -Script $entry -ArgList @('-LogDir', $LogDir, '-Only', ($only -join ','))
    $file = Get-OutputField $r.output 'PLAN_FILE'
    $plan = $null
    if ($r.exitCode -eq 0 -and $file) { $plan = Read-Json $file }
    $name = $null
    if ($file) { $name = [IO.Path]::GetFileName($file) }
    return [ordered]@{ exitCode = $r.exitCode; output = $r.output; plan = $plan; planFile = $name }
}

function Get-RunLog {
    param([string]$Output)
    $file = Get-OutputField $Output 'LOG_FILE'
    if ($file -and (Test-Path -LiteralPath $file)) { return Read-Json $file }
    return $null
}

function Get-OptionArgs {
    param($Body)
    $o = Get-Field $Body 'options'
    $a = @()
    if ((Get-Field $o 'enableSystemRestore' $false) -eq $true) { $a += '-EnableSystemRestore' }
    if ((Get-Field $o 'allowUntestedBuild' $false) -eq $true) { $a += '-AllowUntestedBuild' }
    return $a
}

function Invoke-GuiApply {
    param($Body)
    $plan = Resolve-LogFile -Name (Get-Field $Body 'planFile') -Prefix 'plan'
    $r = Invoke-Engine -Script $entry -ArgList (@('-LogDir', $LogDir, '-Apply', '-Plan', $plan, '-Elevate') + (Get-OptionArgs $Body))
    return [ordered]@{ exitCode = $r.exitCode; output = $r.output; log = (Get-RunLog $r.output) }
}

function Invoke-GuiRevert {
    param($Body)
    $log = Resolve-LogFile -Name (Get-Field $Body 'logFile') -Prefix 'run'
    $a = @('-LogDir', $LogDir, '-Revert', $log)
    $real = (Get-Field $Body 'apply' $false) -eq $true
    if ($real) { $a += @('-Apply', '-Elevate') + (Get-OptionArgs $Body) }
    $r = Invoke-Engine -Script $entry -ArgList $a
    $doc = $null
    if ($real) { $doc = Get-RunLog $r.output }
    return [ordered]@{ exitCode = $r.exitCode; output = $r.output; log = $doc }
}

function Get-GuiRuns {
    $runs = @()
    if (Test-Path -LiteralPath $LogDir) {
        foreach ($f in (Get-ChildItem -LiteralPath $LogDir -Filter 'run-*.json' -File | Sort-Object Name -Descending | Select-Object -First 50)) {
            try { $d = Read-Json $f.FullName } catch { continue }
            $done = @(@(Get-Field $d 'changes' @()) | Where-Object { $_.status -eq 'changed' -or $_.status -eq 'reverted' })
            $runs += [ordered]@{ file = $f.Name; runId = (Get-Field $d 'runId'); kind = (Get-Field $d 'kind'); startedAt = (Get-Field $d 'startedAt')
                outcome = (Get-Field $d 'outcome'); changed = $done.Count }
        }
    }
    return , @($runs)
}

function Send-Response {
    param($Context, [int]$Code, $Body, [string]$ContentType = 'application/json; charset=utf-8')
    if ($Body -is [string]) { $text = $Body }
    elseif ($Body -is [array] -and $Body.Count -eq 0) { $text = '[]' }
    elseif ($Body -is [array] -and $Body.Count -eq 1) { $text = '[' + (ConvertTo-Json -InputObject $Body[0] -Depth 12 -Compress) + ']' }
    else { $text = ConvertTo-Json -InputObject $Body -Depth 12 -Compress }
    $bytes = $utf8.GetBytes($text)
    $res = $Context.Response
    $res.StatusCode = $Code
    $res.ContentType = $ContentType
    $res.Headers['Cache-Control'] = 'no-store'
    $res.Headers['X-Content-Type-Options'] = 'nosniff'
    $res.Headers['Referrer-Policy'] = 'no-referrer'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

function Test-SameText {
    param([string]$A, [string]$B)
    if ($null -eq $A -or $A.Length -ne $B.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $A.Length; $i++) { $diff = $diff -bor ([int]$A[$i] -bxor [int]$B[$i]) }
    return ($diff -eq 0)
}

# --- listener ------------------------------------------------------------------------------
if ($Port -eq 0) {
    $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $Port = $probe.LocalEndpoint.Port; $probe.Stop()
}
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$raw = New-Object byte[] 24
$rng.GetBytes($raw)
$token = -join ($raw | ForEach-Object { $_.ToString('x2') })
$hosts = @("localhost:$Port", "127.0.0.1:$Port")
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
$url = "http://localhost:$Port/?t=$token"
Write-Output "WINNOW_GUI_URL=$url"
Write-Output 'Local only. Press Ctrl+C or use Quit in the page to stop.'
if (-not $NoBrowser) { Start-Process $url }

$running = $true
try {
    while ($running) {
        $pending = $listener.BeginGetContext($null, $null)
        while (-not $pending.AsyncWaitHandle.WaitOne(250)) { }   # stays responsive to Ctrl+C
        $ctx = $listener.EndGetContext($pending)
        $req = $ctx.Request
        $path = $req.Url.AbsolutePath
        try {
            # Loopback page only: right Host (no DNS rebinding), no foreign Origin, and the token.
            $origin = $req.Headers['Origin']
            if ($hosts -notcontains $req.UserHostName) { Send-Response $ctx 403 @{ error = 'bad host' }; continue }
            if ($origin -and (@($hosts | ForEach-Object { "http://$_" }) -notcontains $origin)) { Send-Response $ctx 403 @{ error = 'bad origin' }; continue }
            if ($path -like '/api/*' -and -not (Test-SameText $req.Headers['X-Winnow-Token'] $token)) { Send-Response $ctx 403 @{ error = 'bad token' }; continue }

            $body = $null
            if ($req.HttpMethod -eq 'POST') {
                if ($req.ContentLength64 -gt 1000000) { Send-Response $ctx 413 @{ error = 'too large' }; continue }
                $reader = New-Object System.IO.StreamReader($req.InputStream, $utf8)
                $text = $reader.ReadToEnd()
                if ($text) { $body = $text | ConvertFrom-Json }
            }
            $route = "$($req.HttpMethod) $path"
            switch ($route) {
                'GET /' {
                    if (-not (Test-SameText $req.QueryString['t'] $token)) { Send-Response $ctx 403 'Open the full URL printed in the terminal.' 'text/plain; charset=utf-8' }
                    else { Send-Response $ctx 200 ([IO.File]::ReadAllText($page)) 'text/html; charset=utf-8' }
                }
                'GET /api/state' { Send-Response $ctx 200 (Get-GuiState) }
                'GET /api/runs' { Send-Response $ctx 200 (Get-GuiRuns) }
                'POST /api/plan' { Send-Response $ctx 200 (New-GuiPlan $body) }
                'POST /api/apply' { Send-Response $ctx 200 (Invoke-GuiApply $body) }
                'POST /api/revert' { Send-Response $ctx 200 (Invoke-GuiRevert $body) }
                'POST /api/quit' { Send-Response $ctx 200 @{ ok = $true }; $running = $false }
                default { Send-Response $ctx 404 @{ error = 'not found' } }
            }
        }
        catch [ArgumentException] { try { Send-Response $ctx 400 @{ error = $_.Exception.Message } } catch { } }
        catch { try { Send-Response $ctx 500 @{ error = "$($_.Exception.Message)" } } catch { } }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
