# Regression tests for the correctness fixes.
#
# Each test names the fault it pins down. They are regression tests, not a conformance
# harness: docs/spec.md section 10 defines a five-point interoperability check that still
# needs building on top of these.
#
# Pester 5+ splits discovery from run and does not carry file-scope variables across that
# boundary, so every fixture lives in BeforeAll. The script under test does work at import
# time, so its functions are extracted and defined in the global scope rather than
# dot-sourced.

BeforeAll {
    # tool/ holds what executes; the repository root above it holds the vaults and docs.
    $script:ToolRoot    = Split-Path -Parent $PSScriptRoot
    $script:ProjectRoot = Split-Path -Parent $script:ToolRoot
    $script:RealScript = Join-Path $script:ToolRoot 'scripts\sync-ai-shared.ps1'
    $script:ShimScript = Join-Path $script:ToolRoot 'sync-ai-shared.ps1'
    $script:RealText   = [IO.File]::ReadAllText($script:RealScript)
    $script:ShimText   = [IO.File]::ReadAllText($script:ShimScript)

    function global:Get-ParamNames([string]$text) {
        $seg = $text.Substring($text.IndexOf('param('))
        $seg = $seg.Substring(0, $seg.IndexOf("`n)"))
        $seg = ($seg -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $names = [regex]::Matches($seg, '\$([A-Za-z][A-Za-z0-9]*)') |
            ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne 'env' }
        return @($names)
    }

    function global:Import-FunctionFromScript([string]$text, [string]$name) {
        $esc = [regex]::Escape($name)
        # One-liners (Ensure-Dir) have no closing brace at column 0.
        $m = [regex]::Match($text, '(?m)^function\s+' + $esc + '\b[^\r\n]*\{[^\r\n]*\}[^\r\n]*$')
        if (-not $m.Success) {
            $m = [regex]::Match($text, '(?ms)^function\s+' + $esc + '\b.*?^\}')
        }
        if (-not $m.Success) { throw "Function not found in script: $name" }
        # Define globally so the It blocks can see it regardless of Pester scoping.
        Invoke-Expression ($m.Value -replace ('^function\s+' + $esc), "function global:$name")
    }

    Import-FunctionFromScript $script:RealText 'Get-MachineKey'
    Import-FunctionFromScript $script:RealText 'Ensure-Dir'
    Import-FunctionFromScript $script:RealText 'Write-Utf8'
    Import-FunctionFromScript $script:RealText 'Convert-ClaudeAgentToToml'

    $script:Work = Join-Path ([IO.Path]::GetTempPath()) ('dotori-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:Work -Force | Out-Null
}

AfterAll {
    if ($script:Work -and (Test-Path -LiteralPath $script:Work)) {
        Remove-Item -LiteralPath $script:Work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Shim and implementation stay in step' {
    It 'exposes exactly the same parameters, in the same order' {
        # -VaultGitOrigin existed only in the implementation, so the parameter documented
        # for bootstrapping a second machine could not be passed through the shim the
        # install instructions tell you to call.
        (Get-ParamNames $script:ShimText) -join ',' |
            Should -Be ((Get-ParamNames $script:RealText) -join ',')
    }
    It 'defaults to Sync on both entry points' {
        # The implementation defaulted to Initialize, so running it with no arguments took
        # the destructive path.
        $script:RealText | Should -Match "\[string\]\`$Mode = 'Sync'"
        $script:ShimText | Should -Match "\[string\]\`$Mode = 'Sync'"
    }
}

Describe 'Machine identity (docs/spec.md section 3)' {
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
        $script:RealText | Should -Match 'machineFingerprint = \$machineFingerprint'
    }
    It 'stops instead of adopting another machine baseline' {
        $script:RealText | Should -Match 'Machine key collision'
    }
}

Describe 'Write-Utf8 replaces atomically' {
    It 'does not reach the target through a bare in-place copy' {
        # docs/multi-machine.md promised a rename; the code used [IO.File]::Copy, which
        # opens and rewrites the destination in place - the very write it claimed to avoid.
        $script:RealText | Should -Match '\[IO\.File\]::Replace'
        $script:RealText | Should -Match '\[IO\.File\]::Move'
    }
    It 'creates a new file with the exact content and no BOM' {
        $target = Join-Path $script:Work 'new.md'
        Write-Utf8 $target 'hello'
        [IO.File]::ReadAllText($target) | Should -Be 'hello'
        (Get-Content -LiteralPath $target -Encoding Byte -TotalCount 3) -join ',' |
            Should -Not -Be '239,187,191'
    }
    It 'actually takes the atomic path, not the fallback' {
        # The fallback exists for filesystems that cannot do an atomic replace, and it warns
        # when it fires. It fired on every overwrite: [IO.File]::Replace was being handed
        # $null for its backup-path argument, PowerShell bound that as an empty string, and
        # Replace rejected it. The fix was invisible without this assertion - the file
        # contents were correct either way, and only the warning said the guarantee was gone.
        $target = Join-Path $script:Work 'atomic.md'
        Write-Utf8 $target 'first'
        # Write-Utf8 is a plain function, so -WarningVariable does not apply to it; 3>&1
        # merges the warning stream into output, and the function returns nothing otherwise.
        $emitted = Write-Utf8 $target 'second' 3>&1
        ($emitted | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }) |
            Should -BeNullOrEmpty
    }
    It 'overwrites an existing file and leaves no temp file behind' {
        $target = Join-Path $script:Work 'existing.md'
        Write-Utf8 $target 'first'
        Write-Utf8 $target 'second'
        [IO.File]::ReadAllText($target) | Should -Be 'second'
        @(Get-ChildItem -LiteralPath $script:Work -Filter '*.tmp-*').Count | Should -Be 0
    }
}

Describe 'Agent conversion keeps what the definition declares' {
    It 'reads a plain scalar description' {
        # The repository's own example agent is this shape and converted to
        # description = "" without a warning.
        $raw = "---`nname: r`ndescription: Reviews a draft before it ships.`ntools: Read, Glob`n---`nBody."
        Convert-ClaudeAgentToToml $raw 'r' |
            Should -Match 'description = "Reviews a draft before it ships\."'
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
        $sample = Join-Path $script:ProjectRoot 'docs\examples\sample-workspace\vault_ai\agents\example-reviewer.md'
        $toml = Convert-ClaudeAgentToToml ([IO.File]::ReadAllText($sample)) 'example-reviewer'
        $toml | Should -Not -Match 'description = ""'
    }
}

Describe 'Session hooks are installed deliberately' {
    It 'only writes hooks in Initialize mode' {
        # The Stop hook fires after every turn, so an ungated installer rewrote the
        # runtime settings file continuously.
        $script:RealText | Should -Match "(?s)if \(\`$Mode -eq 'Initialize'\) \{\s*\r?\n\s*Add-HookCommand"
    }
    It 'leaves the settings file untouched when the hook is already correct' {
        $script:RealText | Should -Match 'if \(\$current -eq \$rendered\) \{ return \}'
    }
}
