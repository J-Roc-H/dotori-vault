BeforeAll {
    $script:RealScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\sync-ai-shared.ps1'
    $script:Text = [IO.File]::ReadAllText($script:RealScript)
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($script:Text, [ref]$tokens, [ref]$parseErrors)
    foreach ($name in @('Ensure-Dir','Write-Utf8','Get-FrontmatterField','Test-MemoryEvidence')) {
        $node = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}, $true)
        Invoke-Expression ($node.Extent.Text -replace ('^function ' + $name), ('function global:' + $name))
    }
    $script:Work = Join-Path ([IO.Path]::GetTempPath()) ('dotori-safety-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:Work -Force | Out-Null
    function New-EvidenceFixture([string]$name, [string]$fields) {
        $path = Join-Path $script:Work ($name + '.md')
        [IO.File]::WriteAllText($path, "---`nname: fixture`nmetadata:`n$fields`n---`nbody")
        return $path
    }
}
AfterAll {
    $resolved = [IO.Path]::GetFullPath($script:Work)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path $resolved -Leaf) -like 'dotori-safety-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
Describe 'Named evidence reporting' {
    It 'accepts named inline and block references and structured locators' {
        Test-MemoryEvidence (New-EvidenceFixture 'inline' "  evidence: ['test:case-1']") | Should -BeTrue
        Test-MemoryEvidence (New-EvidenceFixture 'block' "  evidence:`n    - test:case-1") | Should -BeTrue
        Test-MemoryEvidence (New-EvidenceFixture 'structured' "  evidence:`n    - kind: test`n      locator: test:case-1") | Should -BeTrue
    }
    It 'does not mistake an unrelated list or empty evidence for named evidence' {
        Test-MemoryEvidence (New-EvidenceFixture 'empty' "  evidence: []`n  scopes:`n    - global") | Should -BeFalse
        Test-MemoryEvidence (New-EvidenceFixture 'blank' "  evidence:`n  scopes:`n    - global") | Should -BeFalse
        Test-MemoryEvidence (New-EvidenceFixture 'kind-only' "  evidence:`n    - kind: test") | Should -BeFalse
        Test-MemoryEvidence (New-EvidenceFixture 'null' '  evidence: [null]') | Should -BeFalse
        Test-MemoryEvidence (New-EvidenceFixture 'null-scalar' '  evidence: null') | Should -BeFalse
    }
    It 'recognizes a verified SMEM source reference without elevating unverified records' {
        Test-MemoryEvidence (New-EvidenceFixture 'smem' "  verification: verified`n  source_ref: repo:example/project:spec.md") | Should -BeTrue
        Test-MemoryEvidence (New-EvidenceFixture 'unverified' "  verification: unverified`n  source_ref: repo:example/project:spec.md") | Should -BeFalse
    }
}
Describe 'Atomic write failure preserves the existing file' {
    It 'throws on a locked target, leaves the original bytes intact, and removes temporary files' {
        $path = Join-Path $script:Work 'locked.md'
        Write-Utf8 $path 'original'
        $handle = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { { Write-Utf8 $path 'replacement' } | Should -Throw } finally { $handle.Dispose() }
        [IO.File]::ReadAllText($path) | Should -Be 'original'
        @(Get-ChildItem -LiteralPath $script:Work -Filter 'locked.md.tmp-*').Count | Should -Be 0
    }
}
