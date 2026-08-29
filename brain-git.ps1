<#
.SYNOPSIS
    git wrapper for the vault's local mirror repository.

.DESCRIPTION
    The vault lives in a cloud-synced folder, so .git must not live inside it: when two
    machines sync the same repository internals (index, packfiles), the repository
    eventually corrupts.

    Instead the git directory stays local (MirrorRoot) and only the work tree points at
    the vault. Nothing is added inside the vault itself.

    Commits are made automatically by sync-ai-shared.ps1 at the start of every session.
    This wrapper is for a human reading or rolling back that history.

    The defaults match scripts\sync-ai-shared.ps1. Both paths were hardcoded here until
    now - the vault path pointed at one particular person's iCloud folder, with no
    parameter to redirect it, so this file was unusable by anyone else and untestable
    anywhere. Pass -VaultRoot and -MirrorRoot to match whatever you gave the sync script.

    Kept ASCII-only on purpose: this file has no BOM, so PowerShell 5.1 decodes it as ANSI
    and any non-ASCII literal here becomes mojibake.

.EXAMPLE
    .\brain-git.ps1 log --oneline
    .\brain-git.ps1 -VaultRoot 'D:\my-vault' status --short
    .\brain-git.ps1 show HEAD --stat
    .\brain-git.ps1 checkout HEAD~3 -- memory/claude-handoff/some-memory.md
#>
[CmdletBinding()]
param(
    # Must match what sync-ai-shared.ps1 was given, or this reads a different repository
    # than the one the sync writes.
    [string]$VaultRoot = (Join-Path $env:USERPROFILE 'iCloudDrive\iCloud~md~obsidian\Vault_AI'),
    [string]$MirrorRoot = (Join-Path $env:USERPROFILE '.ai-shared-sync'),
    # Not named $Args: that is an automatic variable, and shadowing it is a trap for
    # whoever edits this next.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GitArgs
)

$gitDir = Join-Path $MirrorRoot 'vault-ai.git'
$workTree = $VaultRoot

if (-not (Test-Path -LiteralPath $gitDir)) {
    throw ("Mirror repository not found: $gitDir - pass -MirrorRoot pointing at the same " +
        "folder you gave sync-ai-shared.ps1, or run that script once to create it.")
}
if (-not (Test-Path -LiteralPath $workTree)) {
    throw ("Vault work tree not found: $workTree - pass -VaultRoot pointing at the same " +
        "folder you gave sync-ai-shared.ps1.")
}

if (-not $GitArgs -or $GitArgs.Count -eq 0) {
    Write-Host "git-dir   : $gitDir"
    Write-Host "work-tree : $workTree"
    Write-Host ''
    & git --git-dir=$gitDir --work-tree=$workTree status --short
    Write-Host ''
    & git --git-dir=$gitDir --work-tree=$workTree log --oneline -10
    return
}

& git --git-dir=$gitDir --work-tree=$workTree @GitArgs
exit $LASTEXITCODE
