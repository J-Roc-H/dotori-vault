# The install procedure from README.md, performed literally on whatever machine this runs.
#
# Everything else in tests/ exercises the implementation directly, with paths pointed at a
# scratch tree. That leaves two things nothing had ever executed:
#
#   - the shim at the vault root, which is the entry point the instructions name and the
#     path every session hook is baked with
#   - hook installation into a settings.json that actually exists - the conformance tests
#     deliberately have none, so they cover the skip path and not the writing path, which
#     is the one that edits a file the user depends on
#
# README says the install "has not been run on a genuinely fresh Windows install". On CI
# this runs on a clean runner every commit. That is not the same as a person following the
# words on their own machine - it cannot catch an instruction that is merely confusing -
# but it does mean the steps as written no longer go untested.

BeforeAll {
    # tool/ holds what executes; the repository root above it holds the vaults and docs.
    $global:ToolRoot    = Split-Path -Parent $PSScriptRoot
    $global:ProjectRoot = Split-Path -Parent $global:ToolRoot

    function global:New-FreshMachine {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('dotori-install-' + [Guid]::NewGuid().ToString('N'))
        $m = [pscustomobject]@{
            Root       = $root
            Vault      = (Join-Path $root 'vault')
            ClaudeHome = (Join-Path $root 'claude')
            ClaudeRoot = (Join-Path $root 'claude-root')
            CodexHome  = (Join-Path $root 'codex')
            Antigrav   = (Join-Path $root 'antigravity')
            Mirror     = (Join-Path $root 'mirror')
        }
        foreach ($d in @($m.Vault, $m.ClaudeHome, $m.ClaudeRoot, $m.CodexHome, $m.Antigrav, $m.Mirror)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
        # A runtime that has already written its own settings file. The installer refuses to
        # create one - fabricating another tool's config is how you overwrite defaults it
        # has not chosen - so this is the state in which a hook is actually installed.
        [IO.File]::WriteAllText((Join-Path $m.ClaudeHome 'settings.json'),
            '{"model":"opus","hooks":{}}', (New-Object System.Text.UTF8Encoding))
        return $m
    }

    function global:Install-Documented($m, [string]$mode) {
        # README step 2: the shim goes to the vault root, the implementation to scripts\,
        # and skills\wrapup\ alongside them.
        Copy-Item (Join-Path $global:ToolRoot 'sync-ai-shared.ps1') $m.Vault -Force
        New-Item -ItemType Directory -Path (Join-Path $m.Vault 'scripts') -Force | Out-Null
        Copy-Item (Join-Path $global:ToolRoot 'scripts\sync-ai-shared.ps1') `
            (Join-Path $m.Vault 'scripts') -Force
        Copy-Item (Join-Path $global:ProjectRoot 'vault_ai\skills') $m.Vault -Recurse -Force

        # README step 3: run it through the shim, which is the path the instructions give
        # and the path every session hook will be baked with.
        & (Join-Path $m.Vault 'sync-ai-shared.ps1') -Mode $mode -VaultRoot $m.Vault `
            -ClaudeRoot $m.ClaudeRoot -ClaudeHome $m.ClaudeHome -CodexHome $m.CodexHome `
            -AntigravityHome $m.Antigrav -MirrorRoot $m.Mirror -MachineKey 'FRESH-1' `
            -WarningAction SilentlyContinue 3>$null 6>$null | Out-Null
    }

    $global:InstallRoots = @()
    function global:Register-Install($m) { $global:InstallRoots += $m.Root; return $m }
}

AfterAll {
    foreach ($r in $global:InstallRoots) {
        Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'The install procedure in README.md, performed literally' {
    It 'looks first without touching anything (step 1)' {
        $m = Register-Install (New-FreshMachine)
        $settings = Join-Path $m.ClaudeHome 'settings.json'
        $before = [IO.File]::ReadAllText($settings)

        Install-Documented $m 'Report'

        # The copies in step 2 are the operator's doing; what matters is that the run
        # itself changed nothing in the runtime it was pointed at.
        [IO.File]::ReadAllText($settings) | Should -Be $before
        (Join-Path $m.Mirror 'machine-id') | Should -Not -Exist
    }

    It 'runs through the shim at the vault root, not just the implementation' {
        # The shim had only ever been checked statically, for parameter parity. Every
        # session hook points at it, and a machine whose hook is broken can never run the
        # sync that would deliver the fix - so it failing silently is unrecoverable.
        $m = Register-Install (New-FreshMachine)
        { Install-Documented $m 'Initialize' } | Should -Not -Throw
        (Join-Path $m.Vault 'sync\sync-log-FRESH-1.md') | Should -Exist
    }

    It 'writes the session hooks into a settings file that already exists' {
        # The conformance tests have no settings.json on purpose, so they cover the skip
        # path. This covers the writing path - the one that edits a file the user relies on.
        $m = Register-Install (New-FreshMachine)
        Install-Documented $m 'Initialize'

        $j = Get-Content -LiteralPath (Join-Path $m.ClaudeHome 'settings.json') -Raw | ConvertFrom-Json
        $commands = @($j.hooks.SessionStart[0].hooks + $j.hooks.Stop[0].hooks |
            ForEach-Object { $_.command })
        ($commands | Where-Object { $_ -match 'sync-ai-shared\.ps1' }).Count | Should -BeGreaterThan 1
        # The hook must point at the shim, never at the implementation: the shim's path is
        # what both machines bake in, and it is the file that must not move.
        foreach ($c in $commands) { $c | Should -Not -Match 'scripts\\sync-ai-shared\.ps1' }
    }

    It 'keeps settings it did not put there' {
        $m = Register-Install (New-FreshMachine)
        Install-Documented $m 'Initialize'
        $j = Get-Content -LiteralPath (Join-Path $m.ClaudeHome 'settings.json') -Raw | ConvertFrom-Json
        $j.model | Should -Be 'opus'
    }

    It 'backs the settings file up before its first edit' {
        # README promises this in the uninstall section, which is where someone goes when
        # they want the original back.
        $m = Register-Install (New-FreshMachine)
        Install-Documented $m 'Initialize'
        @(Get-ChildItem -LiteralPath (Join-Path $m.Mirror 'backups') -Recurse -Filter 'settings.json').Count |
            Should -BeGreaterThan 0
    }

    It 'seeds the vault and publishes the shipped wrapup skill into the runtime' {
        $m = Register-Install (New-FreshMachine)
        Install-Documented $m 'Initialize'

        foreach ($d in @('agents', 'skills', 'memory', 'sync')) {
            (Join-Path $m.Vault $d) | Should -Exist
        }
        # The skill a new installation is told to copy has to arrive where the agent reads
        # it, or the routine the docs point at does not exist on the machine.
        (Join-Path $m.ClaudeHome 'skills\wrapup\SKILL.md') | Should -Exist
    }

    It 'is idempotent: installing twice reports nothing to do' {
        $m = Register-Install (New-FreshMachine)
        Install-Documented $m 'Initialize'
        Install-Documented $m 'Sync'
        [IO.File]::ReadAllText((Join-Path $m.Vault 'sync\sync-log-FRESH-1.md')) |
            Should -Match 'Memory: pushed 0 / pulled 0 / normalized 0 / conflicts 0'
    }
}
