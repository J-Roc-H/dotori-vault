# DOTORI

**DOcuments TO Real Intelligence**

*일터에서 하던 작업을 집에서 그대로 이어서. 규칙·스킬·기억이 기기와 AI를 따라옵니다.*

> **Windows-first, on purpose.** PowerShell 5.1, nothing to install, no runtime to manage.
> Most tooling in this space assumes a Unix machine and leaves Windows users to adapt it;
> this one is the other way round.
>
> Not on Windows? [docs/spec.md](docs/spec.md) is the on-disk contract — this script is one
> implementation of it, and a second one on another platform can share the same vault.

You tune an AI coding agent at work until it actually knows how you work. Then you get
home, open the same agent on your own machine, and it knows none of it.

DOTORI carries that setup between the machines you use — the same rules, the same skills,
the same agent definitions, the same memory — from one shared folder of plain Markdown.
It does the same across agents, so what you taught one is not lost when you use another.

No database. No service. No daemon. No `.git` directory inside your cloud-synced vault.

## The problem it solves

Two machines you cannot merge: the one at work and the one at home. Same person, same
habits, two environments that drift apart the moment you configure either one.

Two things make that harder than it sounds:

- **The work machine is not fully yours.** You may not be able to push it to a personal
  git remote, and you should not want everything on it leaving in the first place.
- **What each machine knows differs**, and neither should overwrite the other's view.

DOTORI keeps one source of truth and publishes it outward:

```
                      shared vault (Markdown)
                              |
        +---------------------+---------------------+
        |                     |                     |
     at work               at home              machine N
        |                     |                     |
   agent A, B, ...       agent A, B, ...       agent A, B, ...
```

**Neither dimension has a fixed size.** Two is the case it was built for, but nothing in
the code counts machines — keys come from the account running the sync, so a third takes
zero code changes. And it is useful on a single machine too, if what you want is several
agents sharing one set of skills and definitions. A runtime that is not installed is
skipped with a warning, never an error.

### Why a cloud folder and not a git remote

Because one of these machines is usually a work machine. Pushing it to your personal
remote may be against policy, technically blocked, or simply something you do not want.
A synced folder crosses that boundary where a remote will not.

The git history is still there — it just lives outside the vault, on each machine, and
pushing anywhere is a separate decision you make deliberately.

## What it does

- **Publishes shared agents and skills** from one source into each installed runtime,
  converting Markdown agent definitions into whatever format the target expects.
- **Syncs memory in both directions** between each machine's local agent memory and the
  shared archive, using a three-way hash comparison against the previous run.
- **Stops on real conflicts instead of merging.** If both sides genuinely changed, nothing
  is touched and the conflict is logged. No automatic merge, no silent overwrite.
- **Does not stop on fake ones.** If both sides "changed" but the text is identical once a
  byte-order mark and carriage returns are discounted, it converges the bytes and moves on.
  See [docs/sync.md](docs/sync.md) — this distinction is the difference between a sync that
  keeps running and one that quietly freezes.
- **Never propagates deletions.** A memory missing locally is restored from the archive.
  Retiring a memory should be deliberate, not a side effect of sync.
- **Gives each machine its own memory index**, so two machines cannot overwrite each
  other's view of what they know.
- **Commits vault history** to a git repository kept outside the vault.

## Why the git directory lives outside the vault

If your vault sits in iCloud Drive, Dropbox, or OneDrive and two machines sync the same
`.git` internals (`index`, packfiles), the repository will eventually corrupt.

DOTORI keeps the git directory local and points only the work tree at the vault:

```
GIT_DIR   = %USERPROFILE%\.ai-shared-sync\vault-ai.git
WORK_TREE = <your vault>
```

Nothing is added inside the vault.

## What you need

| Required | |
|---|---|
| Windows with PowerShell 5.1 | Ships with the OS. Nothing to install |
| A folder that syncs between your machines | **Any** service — iCloud Drive, Google Drive, Dropbox, OneDrive, Syncthing. Nothing here talks to a cloud API; it just has to be a folder that appears on both machines. See [docs/multi-machine.md](docs/multi-machine.md) for how services differ in the one way that matters |
| The agent runtimes you want to use | Install them first; see the note under Install |

| Not required | |
|---|---|
| A note-taking app | The vault is plain Markdown folders. Obsidian opens it happily and so does anything else; nothing here depends on one. The `.obsidian/` entries in the git exclude list are inert if you do not use it |
| iCloud specifically | The **default path** happens to point at one, because defaults have to point somewhere. Override it with `-VaultRoot`. If the folder you name does not exist, the install stops rather than quietly creating a local folder that syncs nowhere |
| git | Only for keeping vault history. Sync works without it; a missing or failing git is logged and skipped |
| python | Only for the optional search index, which is not part of this repository |

## Install

1. Copy `sync-ai-shared.ps1` (the shim) and `scripts\sync-ai-shared.ps1` into your vault
   root and `scripts\` respectively.
2. Run once to seed the folders and install the session hooks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<vault>\sync-ai-shared.ps1" -Mode Initialize
```

3. After that it runs itself at the start of every session.

**Install your agent runtimes first.** The hook that makes step 3 true is written into
each runtime's own settings file, and this will not create a settings file that a runtime
has not written yet — fabricating one is a good way to overwrite defaults it has not
chosen. If a runtime is missing, the run says so and skips it; install the runtime, then
run this again.

**Read this before step 2.** `-Mode Initialize` writes session hooks into your agent
runtimes' settings files. It is not a dry run. If you want to see what it would touch
first, read the `Add-HookCommand` calls at the bottom of `scripts\sync-ai-shared.ps1`.

**The default paths are one person's setup**, including the vault location. Every one of
them is a parameter — pass `-VaultRoot`, `-ClaudeHome`, `-CodexHome`, `-MirrorRoot` rather
than rearranging your disk to match:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<vault>\sync-ai-shared.ps1" `
  -Mode Initialize -VaultRoot "D:\my-vault"
```

**Do not delete the shim at the vault root.** Every machine bakes that path into its
session hook, and a machine whose hook is broken can never run the sync that would
deliver the fix.

## Reading the log

Every run writes `sync\sync-log-<machine>.md`:

```
Agents synced: 5
Runtimes: agent-a agents=5 skills=14 | agent-b agents=5 skills=14 | agent-c agents=n/a skills=14
Skills synced: 14 skill(s) / 14 file(s)
Memory: pushed 3 / pulled 0 / normalized 0 / conflicts 0
Mirror: committed 4 path(s)
Lifecycle: active=80 verified=6 / no-status=0
Cloud conflict copies: 0
```

`Cloud conflict copies` is your sync service telling on itself: it renamed a losing write
instead of merging it, and one of the two files holds work that never crossed over. They
are listed, never deleted for you.

`Runtimes` is per-runtime on purpose. One aggregate number hides a runtime that silently
received nothing.

`Conflicts` above zero means two machines made genuinely different edits to the same file.
Open the listed paths, decide which side is right, resolve it explicitly. The tool will
not choose for you. `normalized` counts the ones it resolved itself because there was
nothing to decide.

`no-status` counts memories missing their lifecycle field — see [docs/memory.md](docs/memory.md).

## Documentation

| Document | What it covers |
|---|---|
| [docs/spec.md](docs/spec.md) | The on-disk contract, for writing another implementation |
| [docs/multi-machine.md](docs/multi-machine.md) | How machines and runtimes scale, and why neither is a fixed list |
| [docs/routing.md](docs/routing.md) | Giving an agent the context for the task instead of everything |
| [docs/sync.md](docs/sync.md) | The three-way comparison, and real versus encoding-only conflicts |
| [docs/memory.md](docs/memory.md) | Memory folders, and the constraint that only one is auto-loaded |
| [docs/handoff.md](docs/handoff.md) | Machine-to-machine work orders, and why they are not memories |
| [docs/candidates.md](docs/candidates.md) | Promoting agent findings into human knowledge |
| [docs/projects.md](docs/projects.md) | Project working context |
| [docs/index.md](docs/index.md) | Reserved for a search index |
| [docs/evolution.md](docs/evolution.md) | How this architecture arrived at its current shape |
| [human-vault/](human-vault/README.md) | The human side: folder skeleton and templates |
| [examples/sample-workspace/](examples/sample-workspace/README.md) | A miniature of both vaults, with invented content |
| [CHANGELOG.md](CHANGELOG.md) | What changed and why |

If you only read one, read [docs/evolution.md](docs/evolution.md). The code is specific to
one platform; the failures behind it are not.

## If one of your machines belongs to an employer

Read this before pointing it at a work machine.

**Check what you are allowed to move.** This tool copies files out of that machine into a
cloud-synced folder, and optionally into a git remote. Both are exfiltration paths as far
as an employer is concerned, however innocuous the content feels. Whether that is
acceptable is a policy question, not a technical one, and it is yours to answer first.

**The publish gate does not protect you here.** The allowlist and its fail-closed scrub
exist for producing a *public* repository. They do not inspect what your vault holds, what
the cloud folder receives, or what a private remote stores. Those carry whatever you put
in the vault.

**Practical separation that has held up:**

| Do | Instead of |
|---|---|
| Keep employer-specific values in configuration files that never sync | Hardcoding paths, naming rules, or team policy into shared skills and agents |
| Write the shared skill generically, keep the specifics local | One skill that only makes sense inside one organization |
| Add employer identifiers to the forbidden-pattern list, so the gate fails loudly if one ever reaches the public build | Trusting yourself to notice |

The last one is worth doing even if you never publish. A pattern that fails the build is a
check that runs every time; an intention to be careful is not.

## Known limitations

Stated up front, because finding these yourself is worse than being told.

**It reads an agent runtime's internal memory folder.** Memory sync locates the local
store by walking the runtime's own project directory layout. That layout is undocumented
and can change without notice — when it does, memory sync silently finds nothing while
everything else keeps working. If `Memory source:` in the log is empty or wrong, this is
why. Agent and skill publication do not depend on it.

**Publication targets are per-runtime and not all runtimes accept everything.** The log
prints coverage per runtime; a runtime showing `agents=n/a` has no verified convention for
agent definitions, so nothing is written there. See
[docs/multi-machine.md](docs/multi-machine.md).

**The installer edits your runtime settings files.** See the note under Install.

**Conflicts need a human.** By design. If two machines genuinely diverge on the same
memory, sync stops on that file until you resolve it, and it will stay stopped. Check
`Conflicts` in the log rather than assuming silence means success.

## Scope

Windows and PowerShell 5.1, with no dependency beyond what ships with the OS. Used daily
across several machines and several agent runtimes.

The install above has been rehearsed end to end into an empty directory tree — every path
redirected, nothing of the real setup touched — and that rehearsal found three faults that
years of daily use never could, because each one only appears on a machine that does *not*
already have a working setup. See the changelog. It has not been run on a genuinely fresh
Windows install, so the remaining unknowns are environmental: execution policy, whether git
is present, PowerShell version.

**Mixed setups.** A work machine and a home machine are not always the same OS. The script
is Windows-only; the vault is not. [docs/spec.md](docs/spec.md) defines the layout, hashing
and reconciliation rules precisely enough for another implementation to share a vault with
this one. Nothing else here needs to change for that to work — if you write one, open an
issue.

A note if you extend it: PowerShell 5.1 decodes a BOM-less `.ps1` as ANSI, so any
non-ASCII literal in the script becomes mojibake at runtime. The scripts here are kept
ASCII-only for that reason.

## Feedback

This is a personal setup, shared as it is rather than as a product. Issues are read, but
replies are best-effort and may be slow.

Two kinds of report are especially useful, because they cover ground this cannot reach on
its own:

- **What your sync service does.** The conflict-copy shapes in
  [docs/multi-machine.md](docs/multi-machine.md) were collected from documentation and from
  one service in daily use. If yours leaves something the log does not recognize, the shape
  is easy to add.
- **What a fresh machine does.** The install has been rehearsed into an empty directory
  tree, but never run on a Windows machine that started with nothing.

## License

MIT
