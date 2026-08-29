# The conformance check from docs/spec.md section 10, executed rather than described.
#
# Every path the script touches is a parameter, so two machines sharing one vault can be
# simulated in a temp tree: one shared VaultRoot standing in for the cloud folder, and a
# separate ClaudeHome / CodexHome / AntigravityHome / MirrorRoot per machine. Nothing here
# touches the real environment, and -MachineKey supplies the identity that would otherwise
# come from the computer name.
#
# These are end-to-end: the script runs to completion each time and the assertions read
# the log and the files it produced. That is the point - the unit tests in Wave0.Tests.ps1
# pin individual functions, this pins the behaviour two implementations have to agree on.

BeforeAll {
    $global:RealScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\sync-ai-shared.ps1'

    function global:New-Machine([string]$root, [string]$name) {
        $m = Join-Path $root $name
        foreach ($sub in @('claude\agents', 'claude\skills', 'claude\projects\proj\memory',
                           'codex', 'antigravity', 'mirror', 'claude-root')) {
            New-Item -ItemType Directory -Path (Join-Path $m $sub) -Force | Out-Null
        }
        return [pscustomobject]@{
            Name       = $name
            Key        = $name.ToUpper()
            ClaudeHome = (Join-Path $m 'claude')
            ClaudeRoot = (Join-Path $m 'claude-root')
            CodexHome  = (Join-Path $m 'codex')
            Antigrav   = (Join-Path $m 'antigravity')
            Mirror     = (Join-Path $m 'mirror')
            MemoryDir  = (Join-Path $m 'claude\projects\proj\memory')
        }
    }

    function global:Invoke-Sync($machine, [string]$vault, [string]$mode = 'Sync', [string]$keyOverride) {
        $key = if ($keyOverride) { $keyOverride } else { $machine.Key }
        & $global:RealScript -Mode $mode -VaultRoot $vault `
            -ClaudeRoot $machine.ClaudeRoot -ClaudeHome $machine.ClaudeHome `
            -CodexHome $machine.CodexHome -AntigravityHome $machine.Antigrav `
            -MirrorRoot $machine.Mirror -MachineKey $key `
            -WarningAction SilentlyContinue 3>$null | Out-Null
    }

    function global:Get-SyncLog($machine, [string]$vault) {
        $p = Join-Path $vault ('sync\sync-log-' + $machine.Key + '.md')
        if (-not (Test-Path -LiteralPath $p)) { return '' }
        return [IO.File]::ReadAllText($p)
    }

    function global:New-Memory([string]$dir, [string]$name, [string]$body) {
        $text = @"
---
name: $name
description: fixture $name
metadata:
  node_type: memory
  type: reference
  status: active
  agent: test
  modified: 2026-01-20T14:30:00.000Z
---

$body
"@
        # LF only, no BOM: the encoding-only case needs a known starting point.
        [IO.File]::WriteAllText((Join-Path $dir "$name.md"),
            ($text -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding))
    }

    function global:New-Workspace {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('dotori-conf-' + [Guid]::NewGuid().ToString('N'))
        $vault = Join-Path $root 'vault'
        New-Item -ItemType Directory -Path $vault -Force | Out-Null
        $a = New-Machine $root 'machine-a'
        $b = New-Machine $root 'machine-b'
        return [pscustomobject]@{ Root = $root; Vault = $vault; A = $a; B = $b }
    }

    # A 'function global:' does not share the test file's $script: scope, so the list of
    # directories to clean up has to be global too.
    $global:Workspaces = @()
    function global:Register-Workspace($w) { $global:Workspaces += $w.Root; return $w }
}

AfterAll {
    foreach ($r in $global:Workspaces) {
        Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Conformance: idempotence' {
    It 'reports nothing to do on the second run' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'first body'

        Invoke-Sync $w.A $w.Vault 'Initialize'
        Invoke-Sync $w.A $w.Vault 'Sync'

        Get-SyncLog $w.A $w.Vault |
            Should -Match 'Memory: pushed 0 / pulled 0 / normalized 0 / conflicts 0'
    }
}

Describe 'Conformance: propagation' {
    It 'carries a single-character edit from one machine to the other' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'body v1'

        Invoke-Sync $w.A $w.Vault 'Initialize'
        Invoke-Sync $w.B $w.Vault 'Initialize'      # B pulls the memory
        (Join-Path $w.B.MemoryDir 'mem-one.md') | Should -Exist

        # One character changes on A.
        New-Memory $w.A.MemoryDir 'mem-one' 'body v2'
        Invoke-Sync $w.A $w.Vault
        Invoke-Sync $w.B $w.Vault

        [IO.File]::ReadAllText((Join-Path $w.B.MemoryDir 'mem-one.md')) | Should -Match 'body v2'
    }
}

Describe 'Conformance: real conflict' {
    It 'reports a conflict and modifies neither side' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'shared start'
        Invoke-Sync $w.A $w.Vault 'Initialize'
        Invoke-Sync $w.B $w.Vault 'Initialize'

        # Genuinely different edits on both machines.
        New-Memory $w.A.MemoryDir 'mem-one' 'edited on A'
        New-Memory $w.B.MemoryDir 'mem-one' 'edited on B'
        Invoke-Sync $w.A $w.Vault                    # A pushes its version

        $vaultCopy = Join-Path $w.Vault 'memory\claude-handoff\mem-one.md'
        $before = [IO.File]::ReadAllText($vaultCopy)
        $localB = Join-Path $w.B.MemoryDir 'mem-one.md'
        $beforeB = [IO.File]::ReadAllText($localB)

        Invoke-Sync $w.B $w.Vault                    # B sees both sides changed

        Get-SyncLog $w.B $w.Vault | Should -Match 'conflicts 1'
        [IO.File]::ReadAllText($vaultCopy) | Should -Be $before
        [IO.File]::ReadAllText($localB)    | Should -Be $beforeB
    }
}

Describe 'Conformance: encoding-only difference' {
    It 'converges the bytes without reporting a conflict' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'same text both sides'
        Invoke-Sync $w.A $w.Vault 'Initialize'
        Invoke-Sync $w.B $w.Vault 'Initialize'

        # Both sides "change", but only in line endings and a BOM - no decision exists.
        $localB = Join-Path $w.B.MemoryDir 'mem-one.md'
        $text = [IO.File]::ReadAllText($localB)
        [IO.File]::WriteAllText($localB, ($text -replace "`n", "`r`n"),
            (New-Object System.Text.UTF8Encoding $true))
        $vaultCopy = Join-Path $w.Vault 'memory\claude-handoff\mem-one.md'
        # Same text, BOM added: differs from baseline in bytes, identical in content.
        [IO.File]::WriteAllText($vaultCopy, $text, (New-Object System.Text.UTF8Encoding $true))

        Invoke-Sync $w.B $w.Vault

        $log = Get-SyncLog $w.B $w.Vault
        $log | Should -Match 'conflicts 0'
        $log | Should -Match 'normalized [1-9]'
    }
}

Describe 'Conformance: private per-machine files' {
    It 'never lets one machine write the other machine manifest, log or index' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'body'
        Invoke-Sync $w.A $w.Vault 'Initialize'

        $aFiles = @(
            (Join-Path $w.Vault ('sync\sync-manifest-' + $w.A.Key + '.json')),
            (Join-Path $w.Vault ('sync\sync-log-' + $w.A.Key + '.md')),
            (Join-Path $w.Vault ('memory\claude-handoff\MEMORY-' + $w.A.Key + '.md'))
        )
        $before = @{}
        foreach ($f in $aFiles) {
            if (Test-Path -LiteralPath $f) { $before[$f] = (Get-FileHash -LiteralPath $f).Hash }
        }
        $before.Count | Should -BeGreaterThan 0

        New-Memory $w.B.MemoryDir 'mem-two' 'from B'
        Invoke-Sync $w.B $w.Vault 'Initialize'
        Invoke-Sync $w.B $w.Vault 'Sync'

        foreach ($f in $before.Keys) {
            (Get-FileHash -LiteralPath $f).Hash | Should -Be $before[$f]
        }
    }
}

Describe 'Conformance: machine key collision' {
    It 'stops rather than adopting another machine baseline' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'body'
        Invoke-Sync $w.A $w.Vault 'Initialize'

        # B forced onto A's key: different installation, same filenames.
        { Invoke-Sync $w.B $w.Vault 'Sync' $w.A.Key } | Should -Throw -ExpectedMessage '*collision*'
    }
}

Describe 'Publication reaches every installed runtime' {
    It 'converts an agent to Codex TOML with its description intact' {
        # T4 end to end: a plain-scalar description used to arrive empty, and the failure
        # was only visible on a machine whose agents were not written in folded style.
        $w = Register-Workspace (New-Workspace)
        $agent = @"
---
name: example-reviewer
description: Reviews a draft against the project standards before it ships.
tools: Read, Glob, Grep
---

You verify. You do not implement.
"@
        [IO.File]::WriteAllText((Join-Path $w.A.ClaudeHome 'agents\example-reviewer.md'),
            $agent, (New-Object System.Text.UTF8Encoding))

        Invoke-Sync $w.A $w.Vault 'Initialize'

        $toml = Join-Path $w.A.CodexHome 'agents\example-reviewer.toml'
        $toml | Should -Exist
        $text = [IO.File]::ReadAllText($toml)
        $text | Should -Match 'description = "Reviews a draft against the project standards before it ships\."'
        $text | Should -Match 'tools = \["Read", "Glob", "Grep"\]'
    }

    It 'skips a missing runtime instead of failing the run (invariant 6)' {
        $w = Register-Workspace (New-Workspace)
        Remove-Item -LiteralPath $w.A.CodexHome -Recurse -Force
        { Invoke-Sync $w.A $w.Vault 'Initialize' } | Should -Not -Throw
        Get-SyncLog $w.A $w.Vault | Should -Not -BeNullOrEmpty
    }
}

Describe 'Report mode writes nothing' {
    It 'leaves every file and directory exactly as it found them' {
        # The whole value of a pre-flight report is that you can trust it not to act. That
        # is only worth claiming if something checks it, so this lists the entire tree
        # before and after - the runtime homes and the mirror included, not just the vault.
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'body'
        $settings = Join-Path $w.A.ClaudeHome 'settings.json'
        [IO.File]::WriteAllText($settings, '{"hooks":{}}', (New-Object System.Text.UTF8Encoding))

        function Get-Snapshot([string]$root) {
            Get-ChildItem -LiteralPath $root -Recurse -Force |
                ForEach-Object { $_.FullName + '|' + $(if ($_.PSIsContainer) { 'dir' } else { $_.Length }) } |
                Sort-Object
        }
        $before = @(Get-Snapshot $w.Root)
        $before.Count | Should -BeGreaterThan 0

        Invoke-Sync $w.A $w.Vault 'Report'

        (@(Get-Snapshot $w.Root) -join "`n") | Should -Be ($before -join "`n")
        [IO.File]::ReadAllText($settings) | Should -Be '{"hooks":{}}'
    }

    It 'names the settings file it would edit and the hook it would add' {
        $w = Register-Workspace (New-Workspace)
        $out = & $global:RealScript -Mode Report -VaultRoot $w.Vault `
            -ClaudeRoot $w.A.ClaudeRoot -ClaudeHome $w.A.ClaudeHome `
            -CodexHome $w.A.CodexHome -AntigravityHome $w.A.Antigrav `
            -MirrorRoot $w.A.Mirror -MachineKey $w.A.Key `
            -WarningAction SilentlyContinue 6>&1 | Out-String

        # Collapse whitespace before matching. Write-Host output captured through the
        # information stream is wrapped at the console width, which split "-Mode Sync"
        # across a line break and failed an assertion about behaviour that was correct.
        # The report's job is to name these things, not to lay them out on one line.
        $flat = ($out -replace '\s+', ' ')
        $flat | Should -Match 'settings\.json'
        $flat | Should -Match '-Mode Sync'
        $flat | Should -Match ([regex]::Escape($w.A.Key))
    }

    It 'does not create the machine fingerprint file' {
        # It lives outside the vault and is generated on first real run; a report that
        # created it would have quietly made the machine "already installed".
        $w = Register-Workspace (New-Workspace)
        Invoke-Sync $w.A $w.Vault 'Report'
        (Join-Path $w.A.Mirror 'machine-id') | Should -Not -Exist
    }
}

Describe 'Deletions are not propagated (invariant 2)' {
    It 'restores a memory deleted locally rather than removing it from the vault' {
        $w = Register-Workspace (New-Workspace)
        New-Memory $w.A.MemoryDir 'mem-one' 'body'
        Invoke-Sync $w.A $w.Vault 'Initialize'

        Remove-Item -LiteralPath (Join-Path $w.A.MemoryDir 'mem-one.md') -Force
        Invoke-Sync $w.A $w.Vault

        (Join-Path $w.A.MemoryDir 'mem-one.md') | Should -Exist
        (Join-Path $w.Vault 'memory\claude-handoff\mem-one.md') | Should -Exist
    }
}
