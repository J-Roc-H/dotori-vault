<#
.SYNOPSIS
    git wrapper for the vault's local mirror repository.

.DESCRIPTION
    The vault lives in a cloud-synced folder, so .git must not live inside it: when two
    machines sync the same repository internals (index, packfiles), the repository
    eventually corrupts.

    Instead the git directory stays local (%USERPROFILE%\.ai-shared-sync\vault-ai.git) and
    only the work tree points at the vault. Nothing is added inside the vault itself.

    Commits are made automatically by sync-ai-shared.ps1 at the start of every session.
    This wrapper is for a human reading or rolling back that history.

    Kept ASCII-only on purpose: this file has no BOM, so PowerShell 5.1 decodes it as ANSI
    and any non-ASCII literal here becomes mojibake.

.EXAMPLE
    .\brain-git.ps1 log --oneline
    .\brain-git.ps1 show HEAD --stat
    .\brain-git.ps1 diff HEAD~1
    .\brain-git.ps1 checkout HEAD~3 -- memory/claude-handoff/some-memory.md
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$gitDir = Join-Path $PSScriptRoot 'vault-ai.git'
$workTree = Join-Path $env:USERPROFILE 'iCloudDrive\iCloud~md~obsidian\Vault_AI'

if (-not (Test-Path -LiteralPath $gitDir)) { throw "Mirror repository not found: $gitDir" }
if (-not (Test-Path -LiteralPath $workTree)) { throw "Vault work tree not found: $workTree" }

if (-not $Args -or $Args.Count -eq 0) {
    Write-Host "git-dir   : $gitDir"
    Write-Host "work-tree : $workTree"
    Write-Host ''
    & git --git-dir=$gitDir --work-tree=$workTree status --short
    Write-Host ''
    & git --git-dir=$gitDir --work-tree=$workTree log --oneline -10
    return
}

& git --git-dir=$gitDir --work-tree=$workTree @Args
exit $LASTEXITCODE
