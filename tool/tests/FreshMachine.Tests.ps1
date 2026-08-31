# The machine, not the procedure.
#
# Install.Tests.ps1 checks that the steps in README.md work. These check the three things
# README's Scope section names as the unknowns a CI run does not cover:
#
#     "the remaining unknowns are environmental: execution policy, whether git is
#      present, PowerShell version."
#
# All three are machine state rather than human judgement, so a test can create each
# condition deliberately instead of waiting to be lucky. What is left after this is the
# part a test genuinely cannot supply - whether the instructions read clearly to someone
# who did not write them - and docs/fresh-machine-check.md is how that gets done.

BeforeAll {
    $global:ToolRoot    = Split-Path -Parent $PSScriptRoot
    $global:ProjectRoot = Split-Path -Parent $global:ToolRoot

    function global:New-BareMachine {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('dotori-fresh-' + [Guid]::NewGuid().ToString('N'))
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
        [IO.File]::WriteAllText((Join-Path $m.ClaudeHome 'settings.json'),
            '{"model":"opus","hooks":{}}', (New-Object System.Text.UTF8Encoding))
        # The install as README describes it, so these run against the shim the way a
        # session hook would.
        Copy-Item (Join-Path $global:ToolRoot 'sync-ai-shared.ps1') $m.Vault -Force
        New-Item -ItemType Directory -Path (Join-Path $m.Vault 'scripts') -Force | Out-Null
        Copy-Item (Join-Path $global:ToolRoot 'scripts\sync-ai-shared.ps1') `
            (Join-Path $m.Vault 'scripts') -Force
        Copy-Item (Join-Path $global:ProjectRoot 'vault_ai\skills') $m.Vault -Recurse -Force
        return $m
    }

    function global:Get-Splat($m) {
        return @{
            VaultRoot = $m.Vault; ClaudeRoot = $m.ClaudeRoot; ClaudeHome = $m.ClaudeHome
            CodexHome = $m.CodexHome; AntigravityHome = $m.Antigrav
            MirrorRoot = $m.Mirror; MachineKey = 'FRESH-ENV'
        }
    }

    # Run powershell.exe as a child and hand back both streams as text plus a real exit
    # code. See the note in the execution-policy test for why this cannot be the call
    # operator with 2>&1.
    function global:Invoke-Child([string[]]$argList, [string]$dir, [string]$tag) {
        $out = Join-Path $dir "$tag-out.txt"
        $err = Join-Path $dir "$tag-err.txt"
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -NoNewWindow `
            -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ((Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue) + "`n" +
                 (Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue))
        return [pscustomobject]@{ ExitCode = $p.ExitCode; Text = $text }
    }

    $global:FreshRoots = @()
    function global:Register-Fresh($m) { $global:FreshRoots += $m.Root; return $m }
}

AfterAll {
    foreach ($r in $global:FreshRoots) {
        Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A machine without git' {
    It 'finishes the run, says so in the log, and still publishes' {
        # README: "git | Only for keeping vault history. Sync works without it; a missing
        # or failing git is logged and skipped". Every git call sits behind one
        # Get-Command guard, and nothing had ever run with that guard failing.
        $m = Register-Fresh (New-BareMachine)
        $splat = Get-Splat $m
        $originalPath = $env:PATH
        try {
            # Drop every PATH entry that could supply git.exe.
            $env:PATH = (($originalPath -split ';') |
                Where-Object { $_ -and ($_ -notmatch 'git') }) -join ';'

            # Assert the setup worked before asserting anything about the run. Without
            # this the test passes just as happily with git still on PATH - a check that
            # cannot fail, which is worse than one that does.
            (Get-Command git -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty

            { & (Join-Path $m.Vault 'sync-ai-shared.ps1') -Mode Initialize @splat `
                -WarningAction SilentlyContinue 6>$null } | Should -Not -Throw
        } finally {
            $env:PATH = $originalPath
        }

        $log = [IO.File]::ReadAllText((Join-Path $m.Vault 'sync\sync-log-FRESH-ENV.md'))
        $log | Should -Match 'Mirror: git not found'
        # History is the only thing git was for. The rest of the run is unaffected.
        (Join-Path $m.ClaudeHome 'skills\wrapup\SKILL.md') | Should -Exist
    }

    It 'leaves PATH exactly as it found it' {
        # The test above edits process state. If it ever fails to restore it, everything
        # after it in this session runs on a machine that has quietly lost git.
        (Get-Command git -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe 'A machine with a locked-down execution policy' {
    It 'runs the documented command, and refuses the same command without the flag' {
        # README tells people to invoke this as:
        #   powershell -NoProfile -ExecutionPolicy Bypass -File "<vault>\sync-ai-shared.ps1"
        # Whether that flag is load-bearing or cargo cult had never been established.
        $m = Register-Fresh (New-BareMachine)
        $shim = Join-Path $m.Vault 'sync-ai-shared.ps1'

        $original = Get-ExecutionPolicy -Scope Process
        $locked = $false
        try {
            Set-ExecutionPolicy Restricted -Scope Process -Force -ErrorAction Stop
            $locked = ((Get-ExecutionPolicy -Scope Process) -eq 'Restricted')
        } catch {
            $locked = $false
        }

        if (-not $locked) {
            # Group policy can pin this. Skipping is right: a check that cannot run must
            # not be reported as a failure, or people learn to ignore the colour.
            Set-ItResult -Skipped -Because 'the process execution policy could not be set to Restricted here'
            return
        }

        try {
            $q = { param([string]$v) '"' + $v + '"' }
            $common = @('-NoProfile', '-File', (& $q $shim), '-Mode', 'Report',
                        '-VaultRoot', (& $q $m.Vault), '-MirrorRoot', (& $q $m.Mirror),
                        '-ClaudeHome', (& $q $m.ClaudeHome), '-CodexHome', (& $q $m.CodexHome),
                        '-AntigravityHome', (& $q $m.Antigrav), '-MachineKey', 'FRESH-ENV')
            $documented = @('-ExecutionPolicy', 'Bypass') + $common

            # Start-Process rather than the call operator with 2>&1. A refusal is the
            # expected result of the second run, and merging stderr into the pipeline
            # makes it an ErrorRecord - which Pester, running It blocks under
            # ErrorActionPreference = Stop, raises as a terminating error. The assertion
            # is then never reached and the harness reports a failure for the very
            # behaviour the test exists to confirm. This also yields a real exit code.
            $withFlag    = Invoke-Child $documented $m.Root 'with-flag'
            $withoutFlag = Invoke-Child $common     $m.Root 'no-flag'

            # Positive case asserted on output, not exit status: Report returns without
            # running a native command, so "exited 0" would hold whether or not the
            # script ever did anything.
            $withFlag.Text | Should -Match 'what Initialize would do on this machine'

            # Negative case: a Restricted machine refuses to load the file at all.
            $withoutFlag.ExitCode | Should -Not -Be 0
            $withoutFlag.Text | Should -Not -Match 'what Initialize would do on this machine'
        } finally {
            Set-ExecutionPolicy $original -Scope Process -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'The PowerShell this is actually tested on' {
    It 'is Windows PowerShell 5.1' {
        # The whole project is built around 5.1 - the ANSI decoding of BOM-less scripts,
        # the absence of newer operators. CI happens to use it because `shell: powershell`
        # means Windows PowerShell, but nothing said so out loud, which left the central
        # platform claim verified by coincidence.
        $PSVersionTable.PSVersion.Major | Should -Be 5
    }
}
