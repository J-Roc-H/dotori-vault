[CmdletBinding()]
param(
    # Default is Sync, not Initialize. Initialize reseeds folders and writes session
    # hooks into runtime settings files; it must be an explicit choice, never what you
    # get by double-clicking or running this file with no arguments. The root shim has
    # always defaulted to Sync - this file disagreeing with it meant the destructive
    # path was the default on the one entry point that had no guard rail.
    [ValidateSet('Initialize','Sync')][string]$Mode = 'Sync',
    [string]$VaultRoot = (Join-Path $env:USERPROFILE 'iCloudDrive\iCloud~md~obsidian\Vault_AI'),
    [string]$ClaudeRoot = (Join-Path $env:USERPROFILE 'Documents\Claude'),
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE '.claude'),
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    # Remote the local git mirror should adopt history from when bootstrapping on a new
    # machine. Leave empty for a purely local mirror.
    [string]$VaultGitOrigin = '',
    # Where the Antigravity global rules file is written. A directory, not a file path.
    # This was read straight from $env:USERPROFILE until 2026-08-29, which made it the one
    # write in the script no parameter could redirect: a rehearsal run with every other
    # path pointed at a scratch tree still overwrote the real rules file.
    [string]$AntigravityHome = $env:USERPROFILE,
    # Local-only working area. Never inside the vault: backups hold runtime settings
    # (Layer A) and the git dir must not be synced by iCloud between machines.
    [string]$MirrorRoot = (Join-Path $env:USERPROFILE '.ai-shared-sync'),
    # Identifies this machine. Three files are named from it (manifest, log, memory
    # index) and docs/spec.md section 3 requires the value be stable across runs AND
    # distinct between machines.
    #
    # This was $env:USERNAME until now, which satisfies only the first half: USERNAME is
    # an ACCOUNT name, not a machine name. Two machines signed in as the same account -
    # the same person's work and home PC, two boxes both using 'user' or 'Administrator',
    # or one Microsoft account deriving the same local profile on both - collapse onto one
    # set of filenames. That is exactly the failure docs/evolution.md section 5 records
    # (64 conflict copies in 19 hours) and that per-machine naming exists to prevent, and
    # it reports no error while it happens.
    #
    # COMPUTERNAME is the machine. Pass -MachineKey to override it; whatever you pass must
    # still be stable and unique, and Test-MachineIdentity below checks the uniqueness half
    # rather than trusting it.
    [string]$MachineKey = '',
    [int]$KeepBackups = 3
)

$ErrorActionPreference = 'Stop'
$shared = $VaultRoot
$agents = Join-Path $shared 'agents'
$skills = Join-Path $shared 'skills'
$memory = Join-Path $shared 'memory\claude-handoff'
# Per machine, for the same reason MEMORY-<user>.md is (see $sharedIndexName below):
# these two files are rewritten on every SessionStart AND Stop, so with three machines
# writing one shared copy inside iCloud the loser's write came back as a conflict copy -
# 64 of them ("sync-log 2.md" .. "sync-manifest 33.json") piled up in 19 hours on
# 2026-08-23/24. The manifest is also per-machine DATA, not merely a per-machine file:
# files[].claude is the hash of THIS machine's local copy, and handoffSeen is already
# keyed by user for the same reason. One shared copy let the last writer overwrite
# everyone else's baseline - the 2026-08-24 manifest held handoffSeen for <machine-2> alone,
# the other two machines' keys were gone. A missing manifest is safe, not destructive:
# every three-way compare falls through to "both changed" and reports a conflict
# instead of overwriting (see the memory block). Existing copies are seeded per machine
# on migration so no baseline is lost.
# $manifestPath / $logPath are set below, once the machine key is resolved.
# The hook always points at the root shim, never at this file. Both machines have that
# path baked into settings.json / hooks.json and a broken hook cannot self-repair.
$syncScript = Join-Path $VaultRoot 'sync-ai-shared.ps1'
# Where the implementation is installed. Distinct from $syncScript (the root shim the
# hooks call): copying this file over the shim would replace the forwarder with itself.
$installTarget = Join-Path $shared 'scripts\sync-ai-shared.ps1'
$backupRoot = Join-Path $MirrorRoot 'backups'
# Settings files that were not there to install a hook into. Reported at the end, because
# a silently missing hook means the sync never runs again on its own.
$hooksSkipped = @()
$gitDir = Join-Path $MirrorRoot 'vault-ai.git'
# A fresh machine bootstrapping this mirror for the first time must adopt origin's
# history instead of starting an orphan root commit (2026-08-18: a machine's first-ever
# local git-dir init produced an unrelated-histories split against origin/main, which
# already had a full history from another machine). See Invoke-MirrorCommit init block.
# Empty by default, and it must stay that way in anything distributed. This was a
# hardcoded repository URL until 2026-08-29, which meant every install anywhere added one
# particular person's private repository as its origin and tried to fetch from it. Pass
# -VaultGitOrigin when bootstrapping a second machine of your own; leave it unset and the
# mirror is simply local, which is the right default for someone who just installed this.
$vaultGitOrigin = $VaultGitOrigin

# Each machine owns its own memory index. A single shared MEMORY.md would be
# overwritten by whichever machine synced last, silently discarding the other's index.
$localIndexName = 'MEMORY.md'
# $sharedIndexName is set below, once the machine key is resolved.
$memoryRel = 'memory\claude-handoff'

# ---------------------------------------------------------------------------
# Machine identity
#
# docs/spec.md section 3: the key must be stable across runs on this machine AND distinct
# between machines. COMPUTERNAME gives both; USERNAME gave only the first. A key alone
# cannot prove the second half though - two machines really can share a computer name -
# so a fingerprint that no two machines can share is written next to the manifest and
# checked every run. Without that check a collision is silent, and silent is what made
# the original bug expensive.
#
# The fingerprint lives in MirrorRoot (local, never synced), for the same reason the git
# dir does: it is per-machine state, and a synced copy would defeat its purpose.
# ---------------------------------------------------------------------------
function Get-MachineKey([string]$explicit) {
    if ($explicit) { $raw = $explicit }
    elseif ($env:COMPUTERNAME) { $raw = $env:COMPUTERNAME }
    else { $raw = $env:USERNAME }
    if (-not $raw) { throw 'Cannot determine a machine key. Pass -MachineKey explicitly.' }
    # Filename-safe: this becomes part of three filenames inside the vault.
    $clean = ($raw -replace '[^A-Za-z0-9._-]', '-').Trim('-')
    if (-not $clean) { throw "Machine key '$raw' contains no usable characters. Pass -MachineKey." }
    return $clean
}
function Get-MachineFingerprint([string]$root) {
    # A value unique to this installation, generated once and kept out of the vault.
    $path = Join-Path $root 'machine-id'
    if (Test-Path -LiteralPath $path) {
        $existing = (Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue)
        if ($existing) { $existing = $existing.Trim() }
        if ($existing) { return $existing }
    }
    $id = [Guid]::NewGuid().ToString('N')
    Ensure-Dir $root
    [IO.File]::WriteAllText($path, $id, (New-Object System.Text.UTF8Encoding))
    return $id
}


function Hash-File([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
}
function Hash-Norm([string]$p) {
    # Content identity, ignoring a UTF-8 BOM and CR. This is NOT a replacement for
    # Hash-File: the manifest still stores raw byte hashes, because that is what decides
    # whether a file changed at all. This one answers a narrower question asked only
    # after both sides look changed - "is the text actually different, or did something
    # just rewrite the line endings?" Never widen it to ignore other whitespace: trailing
    # spaces inside a memory are content, and collapsing them would hide a real edit.
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $text = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
    $text = $text.TrimStart([char]0xFEFF).Replace("`r", '')
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}
function Find-ConflictCopies([string]$root) {
    # When two machines write the same file, a sync client renames the losing copy instead
    # of merging it - and every service spells that differently. Detect the shape rather
    # than the service, so this reports something useful on a client nobody here has ever
    # tested against. This vault alone has produced both "name 2.ext" and "name(1).ext".
    #
    # Two of the shapes are ambiguous: "Chapter 2.md" is a perfectly ordinary filename.
    # Those only count when the original is sitting right beside them, which is what makes
    # a conflict copy a conflict copy. The marker-bearing shapes need no such test.
    #
    # Left as a report, never an automatic deletion. One of these two files contains work
    # that was not merged, and only a person can say which.
    $found = @()
    if (-not (Test-Path -LiteralPath $root)) { return $found }
    $prefix = $root.TrimEnd('\').Length + 1
    Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Name
        # Syncthing, Dropbox: unmistakable, and localized clients keep the marker in English.
        if ($name -match '\.sync-conflict-\d{8}-\d{6}' -or $name -match '\(conflicted copy') {
            $found += $_.FullName.Substring($prefix)
            return
        }
        # "name 2.ext" (iCloud) and "name(1).ext" (several Windows clients).
        $m = [regex]::Match($name, '^(?<base>.+?)(?: \d+|\(\d+\))(?<ext>\.[^.]+)$')
        if ($m.Success) {
            $sibling = Join-Path $_.DirectoryName ($m.Groups['base'].Value + $m.Groups['ext'].Value)
            if (Test-Path -LiteralPath $sibling) { $found += $_.FullName.Substring($prefix) }
        }
    }
    return @($found)
}
function Ensure-Dir([string]$p) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
function Copy-Tree([string]$src, [string]$dst) {
    if (-not (Test-Path -LiteralPath $src)) { return }
    Ensure-Dir $dst
    Get-ChildItem -LiteralPath $src -File -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length).TrimStart('\')
        $out = Join-Path $dst $rel
        Ensure-Dir (Split-Path $out)
        Copy-Item -LiteralPath $_.FullName -Destination $out -Force
    }
}
function Backup-File([string]$p, [string]$root) {
    if (Test-Path -LiteralPath $p) {
        $out = Join-Path $root ([IO.Path]::GetFileName($p))
        Copy-Item -LiteralPath $p -Destination $out -Force
    }
}
function Write-Utf8([string]$p, [string]$text) {
    # Write to a temp file and RENAME it over the target. Writing in place would truncate
    # the original to 0 bytes if a cloud client holds a lock mid-write (CORE_DEVREF #56).
    #
    # This used [IO.File]::Copy($tmp, $p, $true), which is not a rename: Copy opens the
    # destination and rewrites it in place - the exact non-atomic write the temp file was
    # there to avoid. docs/multi-machine.md promised a rename; only now is it one.
    #
    # [IO.File]::Replace is the atomic path on NTFS and needs the target to exist;
    # Move covers the create case. Both require same-volume paths, which is why $tmp is
    # built beside $p rather than in a temp directory. If the filesystem underneath
    # supports neither (some cloud FUSE mounts), fall back to Copy but SAY SO - a silent
    # downgrade to the unsafe write is how this stopped being true the first time.
    Ensure-Dir (Split-Path $p)
    $enc = New-Object System.Text.UTF8Encoding
    $tmp = $p + '.tmp-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    try {
        [IO.File]::WriteAllText($tmp, $text, $enc)
        if (Test-Path -LiteralPath $p) {
            try {
                [IO.File]::Replace($tmp, $p, $null)
            } catch {
                Write-Warning ("Atomic replace unavailable for $p (" + $_.Exception.Message +
                    "); falling back to a non-atomic copy.")
                [IO.File]::Copy($tmp, $p, $true)
            }
        } else {
            [IO.File]::Move($tmp, $p)
        }
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    } catch {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        throw
    }
}
function Get-FrontmatterField([string]$path, [string]$field) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $raw = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $fm = [regex]::Match($raw, '(?ms)^---\s*(.*?)\s*---')
    if (-not $fm.Success) { return $null }
    # Leading whitespace is allowed: lifecycle fields live nested under metadata:,
    # while name/description sit at the top level.
    $m = [regex]::Match($fm.Groups[1].Value, ('(?m)^[ \t]*' + [regex]::Escape($field) + ':[ \t]*(.*)$'))
    if (-not $m.Success) { return $null }
    $value = $m.Groups[1].Value.Trim().Trim('"', "'")
    if (-not $value) { return $null }
    return $value
}
function Validate-Skill([string]$p, [string]$folder) {
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    $raw = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
    $fm = [regex]::Match($raw, '(?ms)^---\s*(.*?)\s*---')
    if (-not $fm.Success) { return $false }
    $nm = [regex]::Match($fm.Groups[1].Value, '(?m)^name:\s*["'']?([^"''\r\n]+)')
    $ds = [regex]::IsMatch($fm.Groups[1].Value, '(?m)^description\s*:')
    return ($nm.Success -and $ds -and $nm.Groups[1].Value.Trim() -eq $folder)
}
function Convert-ClaudeAgentToToml([string]$raw, [string]$name) {
    $body = [regex]::Match($raw, '(?s)^---\s*(.*?)\s*---\s*(.*)$')
    if (-not $body.Success) { throw "Invalid agent frontmatter: $name" }
    $yaml = $body.Groups[1].Value
    $instructions = $body.Groups[2].Value.Trim()
    # Accept every YAML scalar style a real agent file uses, not just the one this
    # author happens to write. Matching only 'description: >' (folded) meant a plain
    # 'description: text' silently produced description = "" in the TOML - and the
    # example agent shipped in examples/ is exactly that shape, so the repository's own
    # sample data failed its own converter with no warning.
    $descMatch = [regex]::Match($yaml, '(?ms)^description:[ \t]*[>|][-+]?[ \t]*\r?\n(.*?)(?=^\S|\z)')
    if ($descMatch.Success) {
        # Folded/literal block: join the indented continuation lines.
        $desc = ($descMatch.Groups[1].Value -replace '\r?\n\s+', ' ').Trim()
    } else {
        # Plain or quoted scalar on the same line.
        $descMatch = [regex]::Match($yaml, '(?m)^description:[ \t]*(.+?)[ \t]*$')
        $desc = $descMatch.Groups[1].Value.Trim().Trim('"', "'")
    }
    if (-not $desc) {
        # Never emit an empty description in silence. A runtime selects an agent by its
        # description; an empty one is an agent that can never be chosen.
        Write-Warning "Agent '$name' has no parseable description - the converted file will not be selectable."
    }
    $quoted = $desc.Replace('\', '\\').Replace('"', '\"')
    # tools: was dropped entirely by the previous converter, so an agent restricted to
    # read-only tools in its source definition arrived at the other runtime unrestricted.
    $toolsMatch = [regex]::Match($yaml, '(?m)^tools:[ \t]*(.+?)[ \t]*$')
    $toolsLine = ''
    if ($toolsMatch.Success) {
        $toolList = @($toolsMatch.Groups[1].Value.Split(',') |
            ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
        if ($toolList.Count) {
            $toolsLine = 'tools = [' + (($toolList | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']' + "`r`n"
        }
    }
    return 'name = "' + $name + '"' + "`r`n" +
        'description = "' + $quoted + '"' + "`r`n" +
        $toolsLine +
        "developer_instructions = '''" + "`r`n" +
        $instructions.Replace("'''", "''\''") + "`r`n'''" + "`r`n"
}
function Prune-Backups {
    $root = $backupRoot
    if (-not (Test-Path -LiteralPath $root)) { return }
    $dirs = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object LastWriteTime -Descending)
    if ($KeepBackups -lt 0) { $KeepBackups = 0 }
    $dirs | Select-Object -Skip $KeepBackups | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
}
function Add-HookCommand([string]$jsonPath, [string]$command, [string]$hookName = 'SessionStart') {
    # Deliberately do not create the file: fabricating another tool's settings file is a
    # good way to overwrite defaults it has not written yet. But say so. Returning in
    # silence meant an install on a machine where the runtime was not yet present finished
    # with exit code 0, reported success, and installed no hook at all - while the
    # documentation promised it would run at every session from then on.
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        $script:hooksSkipped += $jsonPath
        return
    }
    $j = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $j.hooks) { $j | Add-Member NoteProperty hooks ([pscustomobject]@{}) }
    if (-not $j.hooks.$hookName) { $j.hooks | Add-Member NoteProperty $hookName @() }
    $groups = @($j.hooks.$hookName)
    if ($groups.Count -eq 0) { $groups = @([pscustomobject]@{ hooks = @() }) }
    $hooks = @($groups[0].hooks)
    $hooks = @($hooks | Where-Object { $_.command -notmatch 'setup-ai-shared-sync\.ps1' -and $_.command -notmatch 'sync-ai-shared\.ps1' })
    if (-not ($hooks | Where-Object { $_.command -eq $command })) {
        $hooks += [pscustomobject]@{ type = 'command'; command = $command }
    }
    $groups[0].hooks = $hooks
    $j.hooks.$hookName = $groups
    # Only write when the result actually differs. Every write here is a full
    # ConvertFrom-Json/ConvertTo-Json round trip of somebody's live runtime settings, and
    # PowerShell 5.1's serializer is not lossless (it escapes non-ASCII to \uXXXX,
    # reformats, and truncates past -Depth). Doing that unconditionally meant a rewrite of
    # settings.json on every single invocation. Comparing first makes the no-op case a
    # read, which is what it should always have been.
    $rendered = $j | ConvertTo-Json -Depth 20
    $current = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
    if ($current -eq $rendered) { return }
    $backup = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
    Ensure-Dir $backup
    Backup-File $jsonPath $backup
    Write-Utf8 $jsonPath $rendered
}
function Invoke-MirrorCommit([string]$summary) {
    # History for the vault without putting .git inside iCloud: the git dir lives in
    # MirrorRoot and only the work tree points at the vault. Two machines syncing the
    # same .git through iCloud would corrupt the repository.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return 'git not found' }
        if (-not (Test-Path -LiteralPath (Join-Path $gitDir 'HEAD'))) {
            Ensure-Dir $MirrorRoot
            & git --git-dir=$gitDir --work-tree=$shared init -b main | Out-Null
            & git --git-dir=$gitDir --work-tree=$shared config core.autocrlf false | Out-Null
            & git --git-dir=$gitDir --work-tree=$shared config user.name 'ai-shared-sync' | Out-Null
            & git --git-dir=$gitDir --work-tree=$shared config user.email 'sync@localhost' | Out-Null
            # Try to continue origin's history rather than diverge from it. Best-effort:
            # offline, no origin yet, or an unreachable repo must not block the sync session.
            if ($vaultGitOrigin) {
                & git --git-dir=$gitDir --work-tree=$shared remote add origin $vaultGitOrigin | Out-Null
                & git --git-dir=$gitDir --work-tree=$shared fetch origin main | Out-Null
                $originHead = (& git --git-dir=$gitDir rev-parse origin/main 2>$null)
                if ($LASTEXITCODE -eq 0 -and $originHead) {
                    & git --git-dir=$gitDir --work-tree=$shared symbolic-ref HEAD refs/heads/main | Out-Null
                    & git --git-dir=$gitDir update-ref refs/heads/main $originHead.Trim() | Out-Null
                }
            }
        }
        # Regenerated every session; tracking them would create an empty commit each start.
        $exclude = Join-Path $gitDir 'info\exclude'
        Ensure-Dir (Split-Path $exclude)
        # .brain/* (not .brain/) so the README stays re-includable - git cannot negate a
        # path whose parent directory is excluded. The old one-line ".brain/index.sqlite3"
        # missed iCloud conflict copies ("index 12.sqlite3"), which put 156 junk commits
        # into the mirror by 2026-08-27.
        # graph.json belongs here for the same reason workspace.json does: the editor
        # rewrites it, every machine rewrites its own, and a cloud folder turns that into
        # conflict copies ("graph 2.json" .. "graph 8.json" had accumulated by 2026-08-29).
        # Anything several machines rewrite on their own schedule is editor state, not
        # vault content.
        Write-Utf8 $exclude ".obsidian/workspace.json`r`n.obsidian/workspace-mobile.json`r`n.obsidian/graph.json`r`n.obsidian/graph *.json`r`nsync/sync-manifest*.json`r`nsync/sync-log*.md`r`nbackups/`r`n.brain/*`r`n!.brain/README.md`r`nscripts/__pycache__/`r`n"
        & git --git-dir=$gitDir --work-tree=$shared add -A | Out-Null
        $pending = @(& git --git-dir=$gitDir --work-tree=$shared status --porcelain)
        if ($pending.Count -eq 0) { return 'no changes' }
        & git --git-dir=$gitDir --work-tree=$shared commit -q -m $summary | Out-Null
        return ('committed ' + $pending.Count + ' path(s)')
    } catch {
        return ('git skipped: ' + $_.Exception.Message)
    } finally {
        $ErrorActionPreference = $prev
    }
}

if (-not (Test-Path -LiteralPath $VaultRoot)) {
    if ($Mode -eq 'Initialize') {
        # Create the vault folder, but not the road to it. The default path points inside
        # a particular cloud client's folder, and Ensure-Dir happily builds that whole
        # chain - so on a machine without that client installed, Initialize used to create
        # an ordinary local directory that merely looked like a synced one, report success,
        # and exit 0. Syncing is the entire point of this tool, so "installed, silently
        # syncing nothing" is the worst state it can be in. If the parent does not exist,
        # the location does not exist, and the user has to say where the vault should live.
        $vaultParent = Split-Path -Path $VaultRoot -Parent
        if ($vaultParent -and -not (Test-Path -LiteralPath $vaultParent)) {
            throw ("Cannot create the vault at $VaultRoot - its parent folder " +
                "$vaultParent does not exist. This usually means the default path assumes " +
                "a cloud client you do not have installed. Pass -VaultRoot pointing at a " +
                "folder inside whichever synced folder you actually use, for example: " +
                "-VaultRoot `"`$env:USERPROFILE\Dropbox\dotori-vault`". Any folder works; " +
                "it does not have to be any particular service, and nothing here requires " +
                "a note-taking app.")
        }
        Ensure-Dir $VaultRoot
    }
    else { throw "Vault not found: $VaultRoot" }
}
$machine = Get-MachineKey $MachineKey
$machineFingerprint = Get-MachineFingerprint $MirrorRoot
$manifestPath = Join-Path $shared ('sync\sync-manifest-' + $machine + '.json')
$logPath = Join-Path $shared ('sync\sync-log-' + $machine + '.md')
$sharedIndexName = 'MEMORY-' + $machine + '.md'

# Migration from the USERNAME-keyed names. Seed rather than move: deletions are never
# propagated (invariant 2), and an older implementation still running on another machine
# may be reading the old name. Nothing is removed; the stale copies are reported once.
$legacyKey = $env:USERNAME
$legacyLeftovers = @()
if ($legacyKey -and $legacyKey -ne $machine) {
    $pairs = @(
        @{ old = (Join-Path $shared ('sync\sync-manifest-' + $legacyKey + '.json')); new = $manifestPath },
        @{ old = (Join-Path $shared ('sync\sync-log-' + $legacyKey + '.md'));        new = $logPath },
        @{ old = (Join-Path $memory ('MEMORY-' + $legacyKey + '.md'));
           new = (Join-Path $memory ('MEMORY-' + $machine + '.md')) }
    )
    foreach ($pair in $pairs) {
        if ((Test-Path -LiteralPath $pair.old) -and -not (Test-Path -LiteralPath $pair.new)) {
            Ensure-Dir (Split-Path $pair.new)
            Copy-Item -LiteralPath $pair.old -Destination $pair.new -Force
        }
        if (Test-Path -LiteralPath $pair.old) { $legacyLeftovers += $pair.old }
    }
}

# Collision check. If the manifest under this key was last written by a different
# installation, two machines are sharing one key and each is about to overwrite the
# other's baseline - the failure per-machine naming exists to prevent. Refuse rather
# than proceed: a wrong baseline silently mis-reconciles memory.
$machineCollision = $null
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $probe = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($probe.machineFingerprint -and $probe.machineFingerprint -ne $machineFingerprint) {
            $machineCollision = $probe.machineFingerprint
        }
    } catch { }
}
if ($machineCollision) {
    throw ("Machine key collision: '$machine' is already in use by a different machine " +
        "(fingerprint $machineCollision, this machine is $machineFingerprint). Two machines " +
        "sharing one key overwrite each other's sync baseline and memory index, which is the " +
        "failure per-machine naming exists to prevent - see docs/multi-machine.md. Pass " +
        "-MachineKey with a name unique to this machine, for example: -MachineKey `"$machine-2`".")
}

# A missing consumer is not a failure: this hook runs at every session start and must
# never take the session down just because one runtime is absent on this machine.
$hasClaudeRoot = Test-Path -LiteralPath $ClaudeRoot
$hasCodex = Test-Path -LiteralPath $CodexHome
if (-not $hasClaudeRoot) { Write-Warning "Claude project root not found, skipping its skill source: $ClaudeRoot" }
if (-not $hasCodex) { Write-Warning "Codex home not found, skipping Codex publication: $CodexHome" }

if ($Mode -eq 'Initialize') {
    Ensure-Dir $shared
    if (Test-Path -LiteralPath $manifestPath) {
        $backup = Join-Path (Split-Path $shared -Parent) ('Vault_AI-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Ensure-Dir $backup
        Copy-Item -LiteralPath $shared -Destination (Join-Path $backup 'Vault_AI') -Recurse -Force
    }
    Ensure-Dir $agents; Ensure-Dir $skills; Ensure-Dir $memory
    Copy-Tree (Join-Path $ClaudeHome 'agents') $agents
    if ($hasClaudeRoot) { Copy-Tree (Join-Path $ClaudeRoot '.claude\skills') $skills }
    Copy-Tree (Join-Path $ClaudeHome 'skills') $skills
    $memRoot = Get-ChildItem (Join-Path $ClaudeHome 'projects') -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'memory' } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($memRoot) { Copy-Tree $memRoot $memory }
    if ($hasCodex) { Copy-Tree (Join-Path $CodexHome 'memories\claude-handoff') $memory }
    # CLAUDE.md / AGENTS.md are deliberately NOT copied here: a second durable copy of the
    # operating rules would compete with the shared source (design rule "no competing copies").
    $rules = @"
# AI shared source of truth

This folder is the shared knowledge layer for Claude Code and Codex.

- Read the current Vault_Personal guidance and project devref before editing.
- Verify real files, outputs, and test evidence before declaring completion.
- Keep runtime settings, credentials, plugin caches, and session logs local to each AI.
- Shared skills live under skills\.
- Claude memory archive lives under memory\claude-handoff\.
- Claude/Codex adapters should point here; do not maintain competing copies of durable rules.
"@
    # Seed only. Re-running Initialize must not overwrite the maintained (translated) rules.
    $rulesPath = Join-Path $shared 'shared-rules.md'
    if (-not (Test-Path -LiteralPath $rulesPath)) { Write-Utf8 $rulesPath $rules }
    else { Write-Warning "shared-rules.md already exists, left untouched." }
    # Same self-copy guard the Sync path has had all along (see the end of this file).
    # Its absence here broke the documented install exactly: copy both files into the
    # vault, run Initialize, and source and destination are the same file - Copy-Item
    # refuses to copy an item onto itself, so the install died at its last step with
    # exit code 1. It never showed up on a machine that already had a working setup,
    # because there the running copy and the install target were different paths.
    Ensure-Dir (Split-Path $installTarget)
    if (-not [String]::Equals([IO.Path]::GetFullPath($PSCommandPath), [IO.Path]::GetFullPath($installTarget), [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $installTarget -Force
    }
}

if (-not (Test-Path -LiteralPath $shared)) { throw "Shared source not initialized: $shared" }
Ensure-Dir $agents; Ensure-Dir $skills; Ensure-Dir $memory
$old = $null
if (Test-Path -LiteralPath $manifestPath) { $old = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json }
$oldFiles = @{}
if ($old -and $old.files) { foreach ($x in $old.files) { $oldFiles[$x.relative] = $x } }
# handoffSeen is scoped per machine, keyed by the machine key (the same key MEMORY-<machine>.md
# uses). The manifest is shared via iCloud, so a single flat list let whichever machine
# synced first mark a handoff "seen" for both, and the recipient's "unread on this machine"
# alert never fired (2026-08-18: exactly why <user> got no alert for a handoff <machine-1> wrote).
# A legacy flat array is read as this machine's baseline so upgrading does not replay old
# handoffs as new here.
# Keyed by the resolved machine key, not USERNAME. A manifest written under the old
# USERNAME key was copied to the new name above, so its handoffSeen entry is still keyed
# by the old value; carry that across once so upgrading does not replay old handoffs.
$me = $machine
$oldHandoffSeen = @{}
if ($old -and $old.handoffSeen -and -not ($old.handoffSeen -is [Array]) -and
        -not $old.handoffSeen.$me -and $legacyKey -and $old.handoffSeen.$legacyKey) {
    $old.handoffSeen | Add-Member NoteProperty $me @($old.handoffSeen.$legacyKey) -Force
}
if ($old -and $old.handoffSeen) {
    if ($old.handoffSeen -is [Array]) {
        foreach ($h in $old.handoffSeen) { $oldHandoffSeen[$h] = $true }
    } else {
        $mine = $old.handoffSeen.$me
        if ($mine) { foreach ($h in $mine) { $oldHandoffSeen[$h] = $true } }
    }
}
$records = @()
$agentRecords = @()
$skillRecords = @()
$conflicts = @()
# Counts actual copy events (adopted-local-change or first-seen), not the total file
# count $agentRecords/$skillRecords report every run regardless of whether anything moved.
$sourceChanges = 0
$invalidSkillFolders = @()

# Claude agents are stored as Markdown in Claude and converted to TOML for Codex.
# The shared Markdown copy is the canonical source; Claude itself is never modified.
$claudeAgentRoot = Join-Path $ClaudeHome 'agents'
if (Test-Path -LiteralPath $claudeAgentRoot) {
    Get-ChildItem -LiteralPath $claudeAgentRoot -File -Filter '*.md' | ForEach-Object {
        $rel = $_.Name
        $sharedFile = Join-Path $agents $rel
        $oldRec = $oldFiles[('agents\' + $rel)]
        $sharedHash = Hash-File $sharedFile
        $sourceHash = Hash-File $_.FullName
        $oldShared = if ($oldRec) { $oldRec.shared } else { $null }
        $oldSource = if ($oldRec) { $oldRec.claude } else { $null }
        if ($sourceHash -and $oldSource -and $sourceHash -ne $oldSource -and $sharedHash -eq $oldShared) {
            Copy-Item $_.FullName $sharedFile -Force; $sharedHash = Hash-File $sharedFile; $sourceChanges++
        } elseif ($sourceHash -and $oldSource -and $sourceHash -ne $oldSource -and $sharedHash -ne $oldShared -and $sourceHash -ne $sharedHash) {
            $conflicts += ('agents\' + $rel)
        }
        if (-not (Test-Path -LiteralPath $sharedFile)) { Copy-Item $_.FullName $sharedFile -Force; $sourceChanges++ }
    }
}

# Publish the shared agent definitions to both runtimes.
Get-ChildItem -LiteralPath $agents -File -Filter '*.md' | ForEach-Object {
    $rel = $_.Name
    $agentName = [IO.Path]::GetFileNameWithoutExtension($rel)
    $agentRel = 'agents\' + $rel
    if ($conflicts -contains $agentRel) { return }
    $claudeOut = Join-Path $claudeAgentRoot $rel
    Ensure-Dir (Split-Path $claudeOut)
    Copy-Item $_.FullName $claudeOut -Force
    $codexHash = $null
    if ($hasCodex) {
        $codexOut = Join-Path (Join-Path $CodexHome 'agents') ($agentName + '.toml')
        Ensure-Dir (Split-Path $codexOut)
        $toml = Convert-ClaudeAgentToToml ([IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)) $agentName
        Write-Utf8 $codexOut $toml
        $codexHash = Hash-File $codexOut
    }
    $agentRecords += [pscustomobject]@{ relative=$agentRel; shared=(Hash-File $_.FullName); claude=(Hash-File $claudeOut); codex=$codexHash }
}

# Skills: auto-adopt Claude changes only when the shared copy was not edited.
$claudeSkillRoots = @(
    (Join-Path $ClaudeRoot '.claude\skills'),
    (Join-Path $ClaudeHome 'skills')
)
foreach ($root in $claudeSkillRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\')
        $sharedFile = Join-Path $skills $rel
        $oldRec = $oldFiles[$rel]
        $sharedHash = Hash-File $sharedFile
        $sourceHash = Hash-File $_.FullName
        $oldShared = if ($oldRec) { $oldRec.shared } else { $null }
        $oldSource = if ($oldRec) { $oldRec.claude } else { $null }
        if ($sourceHash -and $oldSource -and $sourceHash -ne $oldSource -and $sharedHash -eq $oldShared) {
            Ensure-Dir (Split-Path $sharedFile); Copy-Item $_.FullName $sharedFile -Force; $sharedHash = Hash-File $sharedFile; $sourceChanges++
        } elseif ($sourceHash -and $oldSource -and $sourceHash -ne $oldSource -and $sharedHash -ne $oldShared -and $sourceHash -ne $sharedHash) {
            $conflicts += $rel
        }
        if (-not (Test-Path -LiteralPath $sharedFile)) { Ensure-Dir (Split-Path $sharedFile); Copy-Item $_.FullName $sharedFile -Force; $sharedHash = Hash-File $sharedFile; $sourceChanges++ }
    }
}

# Validate the shared skill contract before propagating to either AI.
Get-ChildItem -LiteralPath $skills -Directory | ForEach-Object {
    $skillFile = Join-Path $_.FullName 'SKILL.md'
    if (-not (Validate-Skill $skillFile $_.Name)) { $invalidSkillFolders += $_.Name }
}

# Shared skills are authoritative for both consumers after conflict checks.
Get-ChildItem -LiteralPath $skills -File -Recurse | ForEach-Object {
    $rel = $_.FullName.Substring($skills.Length).TrimStart('\')
    $folder = ($rel -split '\\')[0]
    if (($conflicts -contains $rel) -or ($invalidSkillFolders -contains $folder)) { return }
    # Always publish to the primary Claude skills home (~/.claude/skills), the same
    # unconditional target agents use above. The $ClaudeRoot\.claude\skills copy is an
    # extra legacy location only present when $hasClaudeRoot. Without this $ClaudeHome
    # write a machine with no Documents\Claude (e.g. cwd F:\) never received any skills
    # locally even though the shared folder had them.
    $claudeSkillOut = Join-Path (Join-Path $ClaudeHome 'skills') $rel
    Ensure-Dir (Split-Path $claudeSkillOut)
    Copy-Item $_.FullName $claudeSkillOut -Force
    $claudeHash = Hash-File $claudeSkillOut
    if ($hasClaudeRoot) {
        $claudeOut = Join-Path (Join-Path $ClaudeRoot '.claude\skills') $rel
        Ensure-Dir (Split-Path $claudeOut)
        Copy-Item $_.FullName $claudeOut -Force
    }
    $codexHash = $null
    if ($hasCodex) {
        $codexOut = Join-Path (Join-Path $CodexHome 'skills') $rel
        Ensure-Dir (Split-Path $codexOut)
        Copy-Item $_.FullName $codexOut -Force
        $codexHash = Hash-File $codexOut
    }
    # Publish to Antigravity workspace skills (.agents/skills)
    $antigravitySkillOut = Join-Path (Join-Path $VaultRoot '.agents\skills') $rel
    Ensure-Dir (Split-Path $antigravitySkillOut)
    Copy-Item $_.FullName $antigravitySkillOut -Force

    $jrocPath = Join-Path (Split-Path $VaultRoot -Parent) 'Vault_Personal'
    if (Test-Path -LiteralPath $jrocPath) {
        $jrocSkillOut = Join-Path (Join-Path $jrocPath '.agents\skills') $rel
        Ensure-Dir (Split-Path $jrocSkillOut)
        Copy-Item $_.FullName $jrocSkillOut -Force
    }
    $skillRecords += [pscustomobject]@{ relative=$rel; shared=(Hash-File $_.FullName); claude=$claudeHash; codex=$codexHash }
}

# Publish Antigravity global rules to current machine's USERPROFILE\GEMINI.md
$antigravitySource = Join-Path $shared 'source\antigravity-GEMINI.md'
if (Test-Path -LiteralPath $antigravitySource) {
    $userGemini = Join-Path $AntigravityHome 'GEMINI.md'
    $geminiText = [IO.File]::ReadAllText($antigravitySource, [Text.Encoding]::UTF8)
    Write-Utf8 $userGemini $geminiText
}

# Memory moves in both directions. The previous one-way force-copy meant whichever
# machine synced last silently overwrote the other machine's memories, and gave a new
# machine no way to receive anything. Same three-way comparison the agents/skills use.
$memoryRecords = @()
$memPushed = 0
$memPulled = 0
$memNormalized = 0
$memConflicts = @()
$pulledForIndex = @()

$memRoot = Get-ChildItem (Join-Path $ClaudeHome 'projects') -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'memory' } | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($memRoot) {
    Ensure-Dir $memory
    $memPairs = [ordered]@{}
    Get-ChildItem -LiteralPath $memRoot -File -Filter '*.md' | ForEach-Object {
        if ($_.Name -ne $localIndexName) { $memPairs[$_.Name] = $true }
    }
    Get-ChildItem -LiteralPath $memory -File -Filter '*.md' | ForEach-Object {
        # Index files are never pulled. A bare MEMORY.md is a pre-rename leftover and
        # MEMORY-<other>.md belongs to another machine; either would clobber this index.
        if ($_.Name -eq $localIndexName) { return }
        if ($_.Name -like 'MEMORY-*.md') { return }
        if (-not $memPairs.Contains($_.Name)) { $memPairs[$_.Name] = $true }
    }

    foreach ($name in @($memPairs.Keys)) {
        $sharedFile = Join-Path $memory $name
        $localFile = Join-Path $memRoot $name
        $rel = Join-Path $memoryRel $name
        $oldRec = $oldFiles[$rel]
        $oldShared = if ($oldRec) { $oldRec.shared } else { $null }
        $oldLocal = if ($oldRec) { $oldRec.claude } else { $null }
        $sh = Hash-File $sharedFile
        $lh = Hash-File $localFile

        if ($sh -and $lh -and $sh -eq $lh) {
            # already in sync
        } elseif ($lh -and -not $sh) {
            Copy-Item -LiteralPath $localFile -Destination $sharedFile -Force
            $memPushed++
        } elseif ($sh -and -not $lh) {
            # Deletions are not propagated: a memory missing locally is restored from the
            # archive rather than removed from it. Retiring a memory is a deliberate act.
            Copy-Item -LiteralPath $sharedFile -Destination $localFile -Force
            $memPulled++
            $pulledForIndex += $name
        } else {
            $localChanged = ($lh -ne $oldLocal)
            $sharedChanged = ($sh -ne $oldShared)
            if ($localChanged -and -not $sharedChanged) {
                Copy-Item -LiteralPath $localFile -Destination $sharedFile -Force
                $memPushed++
            } elseif ($sharedChanged -and -not $localChanged) {
                Copy-Item -LiteralPath $sharedFile -Destination $localFile -Force
                $memPulled++
            } elseif ((Hash-Norm $localFile) -eq (Hash-Norm $sharedFile)) {
                # Both sides "changed" but the text is identical once a UTF-8 BOM and CR
                # are discounted. On 2026-08-29 eight of fifteen reported conflicts were
                # this and nothing else: a rewriter had left CRLF on two frontmatter lines
                # or added a BOM. Raw SHA256 cannot tell that from a real edit, so sync
                # froze (pushed 0 / pulled 0) and stayed frozen - a conflict keeps its old
                # baseline by design, so nothing self-heals. Converge the bytes toward the
                # local copy and keep going. Not a conflict: no human decision exists here.
                Copy-Item -LiteralPath $localFile -Destination $sharedFile -Force
                $memNormalized++
            } else {
                $memConflicts += $rel
            }
        }
    }

    # A pulled memory the local index does not list is invisible to recall.
    if ($pulledForIndex.Count) {
        $indexPath = Join-Path $memRoot $localIndexName
        $indexText = ''
        if (Test-Path -LiteralPath $indexPath) { $indexText = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8) }
        $added = @()
        foreach ($name in $pulledForIndex) {
            if ($indexText.Contains('(' + $name + ')')) { continue }
            $title = Get-FrontmatterField (Join-Path $memRoot $name) 'name'
            if (-not $title) { $title = [IO.Path]::GetFileNameWithoutExtension($name) }
            $desc = Get-FrontmatterField (Join-Path $memRoot $name) 'description'
            $line = '- [' + $title + '](' + $name + ')'
            # ASCII only: PowerShell 5.1 decodes a BOM-less .ps1 as ANSI, so a literal
            # em dash here would be written into the index as mojibake.
            if ($desc) { $line = $line + ' - ' + $desc }
            $added += $line
        }
        if ($added.Count) {
            if ($indexText.Length -and -not $indexText.EndsWith("`n")) { $indexText = $indexText + "`r`n" }
            Write-Utf8 $indexPath ($indexText + ($added -join "`r`n") + "`r`n")
        }
    }

    # This machine's own index, archived under a machine-scoped name.
    $indexPath = Join-Path $memRoot $localIndexName
    $sharedIndexPath = Join-Path $memory $sharedIndexName
    $relIndex = Join-Path $memoryRel $sharedIndexName
    $oldRec = $oldFiles[$relIndex]
    $oldShared = if ($oldRec) { $oldRec.shared } else { $null }
    $oldLocal = if ($oldRec) { $oldRec.claude } else { $null }
    $sh = Hash-File $sharedIndexPath
    $lh = Hash-File $indexPath
    if ($sh -and $lh -and $sh -eq $lh) {
        # already in sync
    } elseif ($lh -and -not $sh) {
        Copy-Item -LiteralPath $indexPath -Destination $sharedIndexPath -Force; $memPushed++
    } elseif ($sh -and -not $lh) {
        Copy-Item -LiteralPath $sharedIndexPath -Destination $indexPath -Force; $memPulled++
    } elseif ($sh -and $lh) {
        $localChanged = ($lh -ne $oldLocal)
        $sharedChanged = ($sh -ne $oldShared)
        if ($localChanged -and -not $sharedChanged) {
            Copy-Item -LiteralPath $indexPath -Destination $sharedIndexPath -Force; $memPushed++
        } elseif ($sharedChanged -and -not $localChanged) {
            Copy-Item -LiteralPath $sharedIndexPath -Destination $indexPath -Force; $memPulled++
        } elseif ((Hash-Norm $indexPath) -eq (Hash-Norm $sharedIndexPath)) {
            # Same encoding-only divergence the memory loop handles. The index is this
            # machine's own file, so local always wins the byte convergence.
            Copy-Item -LiteralPath $indexPath -Destination $sharedIndexPath -Force; $memNormalized++
        } else {
            $memConflicts += $relIndex
        }
    }

    # Conflicted entries keep their previous baseline so the conflict persists until
    # a human resolves it, instead of being silently adopted on the next run.
    $memPairs[$sharedIndexName] = $true
    foreach ($name in @($memPairs.Keys)) {
        $rel = Join-Path $memoryRel $name
        if ($memConflicts -contains $rel) {
            if ($oldFiles[$rel]) { $memoryRecords += $oldFiles[$rel] }
            continue
        }
        $localName = if ($name -eq $sharedIndexName) { $localIndexName } else { $name }
        $sharedFile = Join-Path $memory $name
        if (-not (Test-Path -LiteralPath $sharedFile)) { continue }
        $memoryRecords += [pscustomobject]@{
            relative = $rel
            shared = (Hash-File $sharedFile)
            claude = (Hash-File (Join-Path $memRoot $localName))
            codex = $null
        }
    }
}

$conflicts += $memConflicts
$records = @($agentRecords + $skillRecords + $memoryRecords)
if ($hasCodex) { Copy-Tree $memory (Join-Path $CodexHome 'memories\claude-handoff') }

# Lifecycle drift. The status field is a convention the AIs follow, not something the
# harness enforces, so a session that rewrites a memory can silently drop it. Reporting
# the count each sync is what keeps the seven states from decaying into dead metadata.
$memoryRootShared = Join-Path $shared 'memory'
$statusCounts = @{}
$missingStatus = @()
if (Test-Path -LiteralPath $memoryRootShared) {
    Get-ChildItem -LiteralPath $memoryRootShared -File -Filter '*.md' -Recurse | ForEach-Object {
        if ($_.Name -like 'MEMORY-*.md' -or $_.Name -eq 'MEMORY.md' -or $_.Name -eq 'README.md') { return }
        $st = Get-FrontmatterField $_.FullName 'status'
        $rel = $_.FullName.Substring($memoryRootShared.Length).TrimStart('\')
        if (-not $st) { $missingStatus += $rel }
        else {
            if (-not $statusCounts.ContainsKey($st)) { $statusCounts[$st] = 0 }
            $statusCounts[$st] = $statusCounts[$st] + 1
        }
    }
}

# schema 2 adds memory\claude-handoff\* records. A schema 1 manifest still loads: files
# with no record fall back to "copy if one side is missing, conflict if both differ".
# Built separately: inlining this in the log array lets -join bind across the + operators
# and split one line into three.
$statusParts = @($statusCounts.Keys | Sort-Object | ForEach-Object { $_ + '=' + $statusCounts[$_] })
$lifecycleSummary = ($statusParts -join ' ') + ' / no-status=' + $missingStatus.Count
# Whatever sync client is underneath, ask the folder what it did. Nobody here can test
# against every service, but a count in the log means an untested one still reports itself.
$cloudConflictCopies = Find-ConflictCopies $shared

# handoff\ is a deliberate cross-machine inbox, not a memory file - it is never synced,
# indexed, or recalled automatically (2026-08-18: confirmed no other code path reads it).
# Without this, a handoff meant to alert the other machine sits there until someone
# happens to think to open the folder. Report anything this manifest hasn't seen before.
$handoffDir = Join-Path $shared 'handoff'
$newHandoff = @()
$allHandoff = @()
if (Test-Path -LiteralPath $handoffDir) {
    Get-ChildItem -LiteralPath $handoffDir -File -Filter '*.md' | ForEach-Object {
        $allHandoff += $_.Name
        if (-not $oldHandoffSeen.ContainsKey($_.Name)) { $newHandoff += $_.Name }
    }
}

# Rewrite only this machine's seen-list; every other machine's key is carried over intact.
# Migrating away from a legacy flat array drops the shared list, so the other machine gets
# a one-time re-scan of current handoffs on its next run under the new scheme, then owns
# its own key from then on.
$handoffSeenOut = [ordered]@{}
if ($old -and $old.handoffSeen -and -not ($old.handoffSeen -is [Array])) {
    foreach ($p in $old.handoffSeen.PSObject.Properties) { $handoffSeenOut[$p.Name] = @($p.Value) }
}
$handoffSeenOut[$me] = @($allHandoff)

# Distinct skill folders, as opposed to the file count reported alongside it.
$skillFolderCount = @($skillRecords | ForEach-Object { ($_.relative -split '\\')[0] } | Sort-Object -Unique).Count

# What each runtime actually received this run. The point of this vault is that every
# machine and every agent ends up with the same working environment, so the log has to
# show per-runtime coverage - a single aggregate number hides a runtime that silently
# got nothing. Antigravity deliberately shows no agent count: its rules file documents
# .agents\skills only, and no agent-definition convention for it has been verified, so
# nothing is published there rather than inventing a path that may never be read.
$runtimeLines = @()
$runtimeLines += ('claude agents=' + $agentRecords.Count + ' skills=' + $skillFolderCount)
$runtimeLines += ('codex ' + $(if ($hasCodex) { 'agents=' + $agentRecords.Count + ' skills=' + $skillFolderCount } else { 'absent' }))
$runtimeLines += ('antigravity agents=n/a skills=' + $skillFolderCount)
$runtimeSummary = $runtimeLines -join ' | '

$manifest = [ordered]@{
    schema = 2
    updated = (Get-Date).ToString('o')
    source = $shared
    # Identifies the installation that wrote this manifest. Read back on the next run: a
    # different value under the same machine key means two machines share the key and are
    # overwriting each other's baseline. Without this the collision is silent.
    machine = $machine
    machineFingerprint = $machineFingerprint
    files = @($records)
    conflicts = @($conflicts)
    handoffSeen = $handoffSeenOut
}
Write-Utf8 $manifestPath ($manifest | ConvertTo-Json -Depth 8)
$gitStatus = Invoke-MirrorCommit ("sync: {0} agents={1} skills={2} mem=+{3}/-{4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $agentRecords.Count, $skillRecords.Count, $memPushed, $memPulled)
$log = @("# AI shared sync log", "", (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), "Mode: $Mode",
    "Agents synced: $($agentRecords.Count)",
    "Runtimes: $runtimeSummary",
    # Count skills AND files. "Skills synced: 16" is a file count, but it reads as a skill
    # count, and there are 14 skills - two of them ship a second file. An earlier version
    # of this label summed agents and skills into one number and a spec was written against
    # the misreading (v1.1 section 0.2). Say which unit is which.
    "Skills synced: $skillFolderCount skill(s) / $($skillRecords.Count) file(s)",
    "Memory source: $memRoot",
    "Memory: pushed $memPushed / pulled $memPulled / normalized $memNormalized / conflicts $($memConflicts.Count)",
    "Machine: $machine",
    "Conflicts: $($conflicts.Count)",
    "Invalid skill folders: $($invalidSkillFolders.Count)",
    "Mirror: $gitStatus",
    "Lifecycle: $lifecycleSummary",
    "Cloud conflict copies: $($cloudConflictCopies.Count)",
    "New handoff files: $($newHandoff.Count)")
if ($legacyLeftovers.Count) {
    $log += ''; $log += '## Superseded per-machine files'
    $log += 'These are named from the old USERNAME-based machine key. Their contents were'
    $log += 'copied to the new machine-keyed names; nothing was deleted. Remove them by hand'
    $log += 'once every machine sharing this vault has run this version at least once.'
    $log += ($legacyLeftovers | ForEach-Object { '- ' + $_ })
}
if ($newHandoff.Count) { $log += ''; $log += '## New handoff files'; $log += ($newHandoff | ForEach-Object { '- ' + $_ }) }
if ($missingStatus.Count) { $log += ''; $log += '## Memory without lifecycle status'; $log += ($missingStatus | ForEach-Object { '- ' + $_ }) }
if ($conflicts.Count) { $log += ''; $log += '## Conflicts'; $log += ($conflicts | ForEach-Object { '- ' + $_ }) }
if ($cloudConflictCopies.Count) {
    $log += ''; $log += '## Cloud conflict copies'
    $log += 'Your sync client renamed a losing write instead of merging it. One of each'
    $log += 'pair holds work that never made it across. Compare them and delete by hand.'
    $log += ($cloudConflictCopies | ForEach-Object { '- ' + $_ })
}
if ($invalidSkillFolders.Count) { $log += ''; $log += '## Invalid skill folders'; $log += ($invalidSkillFolders | ForEach-Object { '- ' + $_ }) }
Write-Utf8 $logPath ($log -join "`r`n")

# Install the same sync command on both SessionStart (pull latest at start) and Stop
# (push this session's changes back out) so the gap between a local edit and Vault_AI
# seeing it is one turn, not "until the next session happens to start".
# Installing hooks is an Initialize job, not something every Sync redoes. These calls sat
# outside the mode check, so the Stop hook - which fires after every turn, not once per
# session - re-entered the installer and rewrote the runtime's settings file continuously.
# The hook, once written, persists; if it is ever removed, run -Mode Initialize again.
$hookCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $syncScript + '" -Mode Sync'
if ($Mode -eq 'Initialize') {
    Add-HookCommand (Join-Path $ClaudeHome 'settings.json') $hookCommand 'SessionStart'
    Add-HookCommand (Join-Path $ClaudeHome 'settings.json') $hookCommand 'Stop'
    if ($hasCodex) {
        Add-HookCommand (Join-Path $CodexHome 'hooks.json') $hookCommand 'SessionStart'
        Add-HookCommand (Join-Path $CodexHome 'hooks.json') $hookCommand 'Stop'
    }
}
if ($hooksSkipped.Count) {
    foreach ($p in ($hooksSkipped | Sort-Object -Unique)) {
        Write-Warning ("No settings file at $p - no hook installed there. Install the " +
            "runtime first, then run this again, or the sync will only run when you " +
            "start it by hand.")
    }
}
Prune-Backups
# Keep the installed copy in Vault_AI in step with this script when invoked from outputs.
# When this script is already running from scripts\, source and destination are identical.
$runningScript = [IO.Path]::GetFullPath($PSCommandPath)
$installedScript = [IO.Path]::GetFullPath($installTarget)
if (-not [String]::Equals($runningScript, $installedScript, [StringComparison]::OrdinalIgnoreCase)) {
    Ensure-Dir (Split-Path $installTarget)
    Copy-Item -LiteralPath $PSCommandPath -Destination $installTarget -Force
}

# A Stop hook fires after every turn, not just once per session. Printing the full
# report every time would flood the transcript with a no-op block on turns that touched
# no shared asset. Full detail still lands in sync-log.md regardless - this only trims
# what gets echoed back into the conversation.
$hasNews = ($conflicts.Count -gt 0) -or ($invalidSkillFolders.Count -gt 0) -or
    ($missingStatus.Count -gt 0) -or ($memPushed -gt 0) -or ($memPulled -gt 0) -or
    ($sourceChanges -gt 0) -or ($gitStatus -ne 'no changes') -or ($newHandoff.Count -gt 0)

# Rebuild the FTS5 search index only when something actually changed - it's a
# derived artifact (see the SQLite FTS index design note in 02_Dev\AI\AI-Shared-Brain),
# not worth touching on no-op syncs. Kept ASCII on purpose: this file has no BOM, so
# PowerShell 5.1 decodes it as ANSI and any non-ASCII literal here becomes mojibake.
# A failure here must never take down the rest of the sync.
if ($hasNews) {
    $indexScript = Join-Path $shared 'scripts\build-brain-index.py'
    $python = Get-Command python -ErrorAction SilentlyContinue
    # Only mention python when there is actually an index script to run. The warning used
    # to fire whenever python was absent, which meant an install that never had the index
    # scripts in the first place complained every session about a missing dependency for a
    # feature it does not have.
    if (Test-Path -LiteralPath $indexScript) {
        if ($python) {
            try {
                & $python.Source $indexScript --vault-root $shared 2>&1 | Out-Null
            } catch {
                Write-Warning ('Brain index rebuild skipped: ' + $_.Exception.Message)
            }
        } else {
            Write-Warning 'Brain index rebuild skipped: python not found on PATH.'
        }
    }
}

if ($hasNews) {
    Write-Host ('Shared source: ' + $shared) -ForegroundColor Green
    Write-Host ('Skills synchronized: ' + $skillRecords.Count)
    Write-Host ('Agents synchronized: ' + $agentRecords.Count)
    Write-Host ('Memory source: ' + $memRoot)
    Write-Host ('Memory pushed/pulled: ' + $memPushed + '/' + $memPulled)
    Write-Host ('Mirror: ' + $gitStatus)
    Write-Host ('Memory without lifecycle status: ' + $missingStatus.Count)
    Write-Host ('Conflicts: ' + $conflicts.Count)
    Write-Host ('Invalid skill folders: ' + $invalidSkillFolders.Count)
    Write-Host ('Backups retained: ' + $KeepBackups)
    if ($newHandoff.Count) {
        Write-Host ('New handoff (unread on this machine): ' + ($newHandoff -join ', ')) -ForegroundColor Yellow
    }
} else {
    Write-Host 'Vault_AI sync: no changes'
}
