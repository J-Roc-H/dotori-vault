# Compatibility shim. The implementation moved to scripts\sync-ai-shared.ps1.
#
# This file must stay at the vault root. Both machines install a SessionStart hook
# pointing at THIS path, and a machine whose hook is broken never runs the sync that
# would deliver the fix - so removing this file would strand the other computer.
#
# Default mode is Sync, not Initialize: Initialize reseeds files and should only ever
# be run deliberately.
#
# The parameter list mirrors the real script because forwarding needs hashtable
# splatting. Splatting an array passes positional values only, so named parameters
# would silently bind to the wrong slot (-KeepBackups landing in -VaultRoot).
[CmdletBinding()]
param(
    [ValidateSet('Initialize', 'Sync')][string]$Mode = 'Sync',
    [string]$VaultRoot,
    [string]$ClaudeRoot,
    [string]$ClaudeHome,
    [string]$CodexHome,
    [string]$AntigravityHome,
    [string]$MirrorRoot,
    [int]$KeepBackups
)

$real = Join-Path $PSScriptRoot 'scripts\sync-ai-shared.ps1'
if (-not (Test-Path -LiteralPath $real)) { throw "Sync script not found: $real" }

$forward = @{}
foreach ($key in $PSBoundParameters.Keys) { $forward[$key] = $PSBoundParameters[$key] }
$forward['Mode'] = $Mode

& $real @forward
exit $LASTEXITCODE
