# Regression tests for the correctness fixes.
#
# Each test names the fault it pins down. They are regression tests, not a conformance
# harness: docs/spec.md section 10 defines a five-point interoperability check that still
# needs building on top of these.
#
# The script under test runs work at import time, so the functions are extracted and
# evaluated in isolation rather than dot-sourced.

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RealScript = Join-Path $RepoRoot 'scripts\sync-ai-shared.ps1'
$ShimScript = Join-Path $RepoRoot 'sync-ai-shared.ps1'
$RealText = [IO.File]::ReadAllText($RealScript)
$ShimText = [IO.File]::ReadAllText($ShimScript)

function Get-ParamNames([string]$text) {
    $start = $text.IndexOf('param(')
    $seg = $text.Substring($start)
    $seg = $seg.Substring(0, $seg.IndexOf("`n)"))
    $seg = ($seg -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
    $names = [regex]::Matches($seg, '\$([A-Za-z][A-Za-z0-9]*)') |
        ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne 'env' }
    return @($names)
}

function Import-FunctionFromScript([string]$text, [string]$name) {
    # Grab "function <name> ... }" at column 0 - every function here is top-level.
    $pattern = '(?ms)^function\s+' + [regex]::Escape($name) + '\b.*?^\}'
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { throw "Function not found in script: $name" }
    Invoke-Expression $m.Value
}

Describe 'Shim and implementation stay in step' {
    It 'exposes exactly the same parameters, in the same order' {
        # -VaultGitOrigin existed only in the implementation, so the parameter documented
        # for bootstrapping a second machine could not be passed through the shim the
        # install instructions tell you to call.
        (Get-ParamNames $ShimText) -join ',' | Should -Be ((Get-ParamNames $RealText) -join ',')
    }
    It 'defaults to Sync on both entry points' {
        # The implementation defaulted to Initialize, so running it with no arguments took
        # the destructive path.
        $RealText | Should -Match "\[string\]\`$Mode = 'Sync'"
        $ShimText | Should -Match "\[string\]\`$Mode = 'Sync'"
    }
}

Describe 'Machine identity (docs/spec.md section 3)' {
    BeforeAll { Import-FunctionFromScript $RealText 'Get-MachineKey' }

    It 'derives the key from the machine, not the account' {
        Get-MachineKey '' | Should -Be ($env:COMPUTERNAME -replace '[^A-Za-z0-9._-]', '-')
    }
    It 'gives two machines distinct keys even when the account name matches' {
        # The exact collision that produced 64 conflict copies in 19 hours.
        (Get-MachineKey 'DESK-A') | Should -Not -Be (Get-MachineKey 'DESK-B')
    }
    It 'keeps the key usable as a filename' {
        Get-MachineKey 'my machine\name' | Should -Be 'my-machine-name'
    }
    It 'refuses a key that would sanitize to nothing rather than guessing' {
        { Get-MachineKey '\\\\' } | Should -Throw
    }
    It 'records a fingerprint in the manifest so a collision is detectable' {
        $RealText | Should -Match 'machineFingerprint = \$machineFingerprint'
    }
    It 'stops instead of adopting another machine baseline' {
        $RealText | Should -Match 'Machine key collision'
    }
}

Describe 'Write-Utf8 replaces atomically' {
    BeforeAll {
        Import-FunctionFromScript $RealText 'Ensure-Dir'
        Import-FunctionFromScript $RealText 'Write-Utf8'
        $script:Work = Join-Path ([IO.Path]::GetTempPath()) ('dotori-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Work -Force | Out-Null
    }
    AfterAll { Remove-Item -LiteralPath $script:Work -Recurse -Force -ErrorAction SilentlyContinue }

    It 'does not reach the target through a bare in-place copy' {
        # docs/multi-machine.md promised a rename; the code used [IO.File]::Copy, which
        # opens and rewrites the destination in place - the very write it claimed to avoid.
        $RealText | Should -Match '\[IO\.File\]::Replace'
        $RealText | Should -Match '\[IO\.File\]::Move'
    }
    It 'creates a new file with the exact content and no BOM' {
        $target = Join-Path $script:Work 'new.md'
        Write-Utf8 $target "hello"
        [IO.File]::ReadAllText($target) | Should -Be 'hello'
        (Get-Content -LiteralPath $target -Encoding Byte -TotalCount 3) -join ',' | Should -Not -Be '239,187,191'
    }
    It 'overwrites an existing file and leaves no temp file behind' {
        $target = Join-Path $script:Work 'existing.md'
        Write-Utf8 $target "first"
        Write-Utf8 $target "second"
        [IO.File]::ReadAllText($target) | Should -Be 'second'
        @(Get-ChildItem -LiteralPath $script:Work -Filter '*.tmp-*').Count | Should -Be 0
    }
}

Describe 'Agent conversion keeps what the definition declares' {
    BeforeAll { Import-FunctionFromScript $RealText 'Convert-ClaudeAgentToToml' }

    It 'reads a plain scalar description' {
        # The repository's own example agent is this shape and converted to
        # description = "" without a warning.
        $raw = "---`nname: r`ndescription: Reviews a draft before it ships.`ntools: Read, Glob`n---`nBody."
        Convert-ClaudeAgentToToml $raw 'r' | Should -Match 'description = "Reviews a draft before it ships\."'
    }
    It 'reads a folded description' {
        $raw = "---`nname: r`ndescription: >`n  Diagnoses crashes`n  from logs.`ntools: Read`n---`nBody."
        Convert-ClaudeAgentToToml $raw 'r' | Should -Match 'description = "Diagnoses crashes from logs\."'
    }
    It 'carries the tools restriction across' {
        # Dropped entirely before, so a read-only agent arrived unrestricted.
        $raw = "---`nname: r`ndescription: x`ntools: Read, Glob, Grep`n---`nBody."
        Convert-ClaudeAgentToToml $raw 'r' | Should -Match 'tools = \["Read", "Glob", "Grep"\]'
    }
    It 'converts the example agent shipped in this repository' {
        $sample = Join-Path $RepoRoot 'examples\sample-workspace\ai-vault\agents\example-reviewer.md'
        $toml = Convert-ClaudeAgentToToml ([IO.File]::ReadAllText($sample)) 'example-reviewer'
        $toml | Should -Not -Match 'description = ""'
    }
}

Describe 'Session hooks are installed deliberately' {
    It 'only writes hooks in Initialize mode' {
        # The Stop hook fires after every turn, so an ungated installer rewrote the
        # runtime settings file continuously.
        $RealText | Should -Match "(?s)if \(\`$Mode -eq 'Initialize'\) \{\s*\r?\n\s*Add-HookCommand"
    }
    It 'leaves the settings file untouched when the hook is already correct' {
        $RealText | Should -Match 'if \(\$current -eq \$rendered\) \{ return \}'
    }
}
