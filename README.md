# DOTORI

### Teach one AI. Keep it across all your AIs.

Claude에서 만든 규칙과 스킬을 Codex를 열어도 그대로 사용합니다.
회사 PC에서 배운 작업 방식은 집 PC에서도 그대로 이어집니다.

**One AI workspace. Any runtime. Any machine.**

No API. No database. No service. No daemon.
No `.git` directory inside your cloud-synced vault.
Just one shared folder of Markdown.

```
                    ┌──────────────┐
                    │    DOTORI    │
                    │ shared state │
                    └──────┬───────┘
         ┌─────────────────┼─────────────────┐
         ↓                 ↓                 ↓
      Claude             Codex          Antigravity
      rules              rules             rules
      skills             skills            skills
      agents             agents             n/a
         │                 │                 │
         └─────────────────┴─────────────────┘
                           │
                       same memory
                           │
                 ┌─────────┴─────────┐
                 ↓                   ↓
              Work PC             Home PC
```

**DOTORI gives multiple AI runtimes one shared working environment.**
Rules, skills, agents and memory live once, then follow you across runtimes and machines.

`n/a` is not a gap to be filled later: Antigravity has no documented convention for agent
definitions, and this publishes nothing to a path it has not verified. The log says `n/a`
for the same reason the diagram does.

*A squirrel buries acorns in scattered places and comes back for them later.
That is the whole idea. (도토리 — acorn.)*

## DOTORI is for you if...

- [ ] **Claude와 Codex를 번갈아 쓴다** — you switch between agent runtimes
- [ ] **AI마다 같은 규칙을 다시 넣는 게 귀찮다** — you re-teach every new agent the same rules
- [ ] **회사와 집에서 같은 AI 환경을 유지하고 싶다** — you want one environment on both machines

## The moment it matters

**Before**

```
   at work                        at home
   ┌──────────────┐               ┌──────────────┐
   │    Claude    │               │    Codex     │
   │              │               │              │
   │  rules       │               │  (nothing)   │
   │  skills      │   ───── ✗ ──> │              │
   │  agents      │               │  "so, let me │
   │  memory      │               │   explain    │
   │              │               │   again..."  │
   └──────────────┘               └──────────────┘
```

**With DOTORI**

```
   at work                        at home
   ┌──────────────┐               ┌──────────────┐
   │    Claude    │               │    Codex     │
   └──────┬───────┘               └──────▲───────┘
          │                              │
          │        ┌──────────────┐      │
          └───────>│    DOTORI    │──────┘
                   │              │
                   │  rules       │
                   │  skills      │
                   │  agents      │
                   │  memory      │
                   └──────────────┘

     "내가 쓰던 AI 작업환경" — the setup you already had, wherever you opened it
```

## You do not need two computers for this to be worth anything

Most of the value shows up on one machine: two agent runtimes reading the same skills and
the same agent definitions, so what you teach one is not lost when you open the other. That
needs no cloud folder and no second computer, and it is the part you can try in ten minutes
— below.

The second machine adds memory that travels. It is the case this was built for, but it is
not the entry price.

## See it in 10 minutes

On a scratch path you delete at the end. Nothing here touches your real vault, settings
files or runtime folders — but that is because **every path is redirected**, not because
there is a safe mode. Build the scratch tree first and reuse it in every command below:

```powershell
$demo = "$env:TEMP\dotori-demo"; $a = "$demo\machine-a"
mkdir "$a\claude\agents", "$a\claude\skills", "$a\claude\projects\demo\memory", `
      "$a\codex", "$a\antigravity", "$a\local", "$demo\vault" -Force | Out-Null
$scratch = @{
  VaultRoot  = "$demo\vault"; ClaudeHome      = "$a\claude"; ClaudeRoot = "$a\claude-root"
  CodexHome  = "$a\codex";    AntigravityHome = "$a\antigravity"
  MirrorRoot = "$a\local";    MachineKey      = 'DEMO-A'
}
```

> **Pass `@scratch` to every command in this section.** `-Mode Initialize` with only
> `-VaultRoot` redirected still writes session hooks into your **real** runtime settings
> files — that is the ordinary install doing its job, aimed at the wrong place.

**1. Look before anything runs.** This mode is read-only: it resolves every path, names
the runtimes it found, and prints the exact hook line it *would* add.

```powershell
.\tool\sync-ai-shared.ps1 -Mode Report @scratch
```

**2. Put one agent in DOTORI** as ordinary Markdown — `demo-reviewer.md`, with a
`description` and a `tools:` restriction in its frontmatter.

**3. Run Initialize** against that same scratch tree:

```powershell
.\tool\sync-ai-shared.ps1 -Mode Initialize @scratch
```

**4. Open the Codex side.** The Markdown you wrote is now in the format that runtime
expects — description and tool restriction intact:

```toml
name = "demo-reviewer"
description = "Checks a draft against the project standards before it ships."
tools = ["Read", "Glob"]
developer_instructions = '''
You verify. You do not implement.
'''
```

**5. Add a second machine** against the same vault. The memory the first one wrote is
already there, without either machine reading the other's sync state.

**That's DOTORI.** That conversion in step 4 is the thing a file-sync tool cannot do for
you, and every run leaves a log saying exactly what moved:

```
Agents synced: 5
Runtimes: agent-a agents=5 skills=14 | agent-b agents=5 skills=14 | agent-c agents=n/a skills=14
Skills synced: 14 skill(s) / 14 file(s)
Memory: pushed 3 / pulled 0 / normalized 0 / conflicts 0
```

The full copy-pasteable walkthrough, including watching it refuse to merge a real
conflict, is [docs/quickstart.md](docs/quickstart.md).

> **Windows and PowerShell 5.1.** That is what its author runs, not a claim that it is
> better there. The spec is the portable part; the script is one implementation of it.

## When NOT to use DOTORI

**If you can put a git remote between your machines, use something else.**
[skillshare](https://github.com/runkids/skillshare) covers sixty-odd agent tools where this
covers three, runs on macOS and Linux as well as Windows, syncs bidirectionally, and is
maintained by people who are not one person with a day job. If your two machines can both
reach the same repository, that is a better tool than this one and you should go and get it.

DOTORI exists for the case where they cannot. On a work machine, pushing your setup to a
personal remote may be against policy, technically blocked, or simply something you do not
want to do. A folder your employer already syncs crosses that boundary where a remote will
not, and everything here follows from that one constraint.

## What is unusual about it

Two things are unusual enough to name, since they are the reason to look at this at all
rather than merely a smaller version of the alternatives:

- **Memory has a lifecycle with a gate on it.** Not "files copied both ways" —
  a status field where `verified` requires *named* evidence (a path, a commit, test output),
  and where inference is explicitly not evidence. Crossing into human knowledge is a second,
  separate axis that only a person may set. Every run counts what claims either without
  having earned it. See [docs/memory.md](docs/memory.md).
- **The layout is a contract, not an implementation detail.** [docs/spec.md](docs/spec.md)
  defines it precisely enough to write a second implementation that shares a vault with this
  one, with nine invariants and a conformance check that
  [runs on every commit](tool/tests/Conformance.Tests.ps1) rather than sitting in prose.

**If you only read one document, read [docs/evolution.md](docs/evolution.md).** Every
structure here replaced one that failed in a specific way, and the failures are the useful
part — most of them are not specific to this tool or this platform.

## The problem it solves

You tune an AI coding agent at work until it actually knows how you work. Then you get
home, open the same agent on your own machine, and it knows none of it.

Two machines you cannot merge: the one at work and the one at home. Same person, same
habits, two environments that drift apart the moment you configure either one.

Two things make that harder than it sounds:

- **The work machine is not fully yours.** You may not be able to push it to a personal
  git remote, and you should not want everything on it leaving in the first place.
- **What each machine knows differs**, and neither should overwrite the other's view.

DOTORI keeps one source of truth and publishes it outward:

```
   <workspace>/                one folder your sync service carries between machines
   |                           (call these two whatever you already call them)
   +-- <your human vault>/     what you know. Nothing publishes out of here
   |
   +-- <your ai vault>/        what your agents know
           |
        +--+------------------+---------------------+
        |                     |                     |
     at work               at home              machine N
        |                     |                     |
   agent A, B, ...       agent A, B, ...       agent A, B, ...
```

**Neither dimension has a fixed size.** Two is the case it was built for, but nothing in
the code counts machines — keys come from the computer name, so a third takes
zero code changes. If two of your machines share a computer name, pass `-MachineKey`; the
run stops with an error rather than letting them overwrite each other. A runtime that is
not installed is skipped with a warning, never an error.

### Why a cloud folder and not a git remote

Covered above, and it is the whole reason this exists rather than being one more skills
syncer. Worth adding: **the git history is still there.** It lives outside the vault, on
each machine, and pushing it anywhere is a separate decision you make deliberately —
not a precondition for the tool to work.

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
| iCloud specifically | The **default path** happens to point at one, because defaults have to point somewhere. Override it with `-VaultRoot`. If its **parent** does not exist — usually because the default assumes a cloud client you do not have — the install stops rather than building that whole chain and reporting success. If the parent exists the folder is created, and `Initialize` warns when the location does not look like one a sync service carries |
| git | Only for keeping vault history. Sync works without it; a missing or failing git is logged and skipped |
| python | Only for the optional search index, which is not part of this repository |

## Install

**Already have DOTORI running?** [docs/upgrading.md](docs/upgrading.md) is the
upgrade — the steps below are for a first install.

1. **Look first.** `-Mode Report` writes nothing at all — it resolves every path, says
   which runtimes it found, and names the settings files it would edit and the exact hook
   line it would add:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<repo>\tool\sync-ai-shared.ps1" `
  -Mode Report -VaultRoot "D:\my-vault"
```

   Everything it prints comes from the same variables the real run uses, so it cannot
   describe one thing and do another. A test lists the whole tree before and after to
   confirm it leaves nothing behind.

2. Copy `tool\sync-ai-shared.ps1` (the shim) and `tool\scripts\sync-ai-shared.ps1` into
   your vault root and its `scripts\` respectively, then `vault_ai\skills\wrapup\` into
   your vault's `skills\`. The last one is the routine that ends a session with something
   written down, and without it the counters below have nothing to count.
3. Run once to seed the folders and install the session hooks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<vault>\sync-ai-shared.ps1" -Mode Initialize
```

4. After that it runs itself at the start of every session.

**Install your agent runtimes first.** The hook that makes step 3 true is written into
each runtime's own settings file, and this will not create a settings file that a runtime
has not written yet — fabricating one is a good way to overwrite defaults it has not
chosen. If a runtime is missing, the run says so and skips it; install the runtime, then
run this again.

**Read this before step 3.** `-Mode Initialize` writes session hooks into your agent
runtimes' settings files. It is not a dry run. If you want to see what it would touch
first, read the `Add-HookCommand` calls at the bottom of `tool\scripts\sync-ai-shared.ps1`.

Only `Initialize` writes them. `Sync` — the mode the hook itself runs — reads those files
and leaves them alone. If a hook is ever removed, run `Initialize` again to put it back.

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
Vault location: C:\Users\you\OneDrive\dotori (OneDrive)
Lifecycle: active=80 verified=6 / no-status=0
Promoted: 3 memory(ies) with a human-vault destination
Legacy promoted status: 0 memory(ies) to migrate
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

`no-status` counts memories missing their lifecycle field. `Promoted` counts the ones a
person has accepted into the human vault — a separate axis from the lifecycle, so a
promoted memory still has a status. See [docs/memory.md](docs/memory.md).

## Documentation

| Document | What it covers |
|---|---|
| [vault_ai/skills/wrapup/](vault_ai/skills/wrapup/SKILL.md) | The finishing routine: what to write down before you stop |
| [docs/upgrading.md](docs/upgrading.md) | Already running it? The whole upgrade, and what the new counts will tell you |
| [docs/quickstart.md](docs/quickstart.md) | Ten minutes on a scratch path: see it work without touching your setup |
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
| [vault_human/](vault_human/README.md) | The human side: folder skeleton and templates |
| [docs/examples/sample-workspace/](docs/examples/sample-workspace/README.md) | A miniature of both vaults, with invented content |
| [tool/brain-git.ps1](tool/brain-git.ps1) | Reading and rolling back the vault's git history by hand |
| [CONTRIBUTING.md](.github/CONTRIBUTING.md) | What this project takes, what it does not, and how fast to expect a reply |
| [CHANGELOG.md](CHANGELOG.md) | What changed and why |

If you only read one, read [docs/evolution.md](docs/evolution.md). The code is specific to
one platform; the failures behind it are not.

## If one of your machines belongs to an employer

Read this before pointing it at a work machine.

**Check what you are allowed to move.** This tool copies files out of that machine into a
cloud-synced folder, and optionally into a git remote. Both are exfiltration paths as far
as an employer is concerned, however innocuous the content feels. Whether that is
acceptable is a policy question, not a technical one, and it is yours to answer first.

**Nothing here inspects what you move.** There is no filter between your machine and the
vault: whatever you put in the vault is what the cloud folder receives and what a private
remote stores. Earlier revisions of this document referred to a publish gate that screened
an extraction step; there is no extraction step any more (see *Where the code lives*), and
no such gate ships here. Do not read this tool as having a safety net it does not have.

**Practical separation that has held up:**

| Do | Instead of |
|---|---|
| Keep employer-specific values in configuration files that never sync | Hardcoding paths, naming rules, or team policy into shared skills and agents |
| Write the shared skill generically, keep the specifics local | One skill that only makes sense inside one organization |
| Add a check that fails loudly if an employer identifier ever reaches a shared file | Trusting yourself to notice |

The last one is the general rule this project keeps relearning: a check that runs every
time beats an intention to be careful. If you publish anything derived from your vault,
write the check before you need it.

## Uninstalling

Nothing here is hard to reverse, but the steps are worth writing down rather than leaving
you to work them out from the source.

1. **Remove the hooks.** In each runtime's settings file — `%USERPROFILE%\.claude\settings.json`,
   and `%USERPROFILE%\.codex\hooks.json` if you use Codex — delete the `SessionStart` and
   `Stop` entries whose command mentions `sync-ai-shared.ps1`. The installer backed each
   file up before its first edit, under `%USERPROFILE%\.ai-shared-sync\backups\<timestamp>\`,
   so you can also restore one of those.

2. **Delete the local working area** if you want the git history gone:
   `%USERPROFILE%\.ai-shared-sync\`. This holds the mirror repository, the settings
   backups, and this machine's identity file. Deleting it loses the vault's version
   history on this machine and nothing else.

3. **Keep or delete the vault**, as you prefer. It is your content in plain Markdown, and
   nothing outside it is needed to read it. The published copies inside each runtime's own
   folders — `agents\`, `skills\` — stay where they are and keep working; they simply stop
   being updated.

That is all of it. There is no service to cancel, no registry key, and nothing running in
the background between sessions.

## Where the code lives

**This repository is the code.** It is not an extract of a private one that gets scrubbed
and copied out periodically — it was, briefly, and that arrangement had a defect worth
naming: the author ran a private copy daily while publishing a different one, so the
published code was the version nobody actually used. Every fault found in the first review
after publication was of exactly that kind — real on a fresh machine, invisible on the one
it grew up on.

So the script here is the script the author runs. A vault holds content — skills, agents,
memory — and that stays private; the code does not live there. If you find a bug, you are
finding it in the same file its author runs.

Which is why the repository is split the way it is:

| | |
|---|---|
| `tool/` | Everything that executes. The shim, the implementation, the tests |
| `vault_ai/` | Starting content for the agent vault. Right now that is the wrapup skill; `Initialize` creates the rest of the folders, because git does not track empty ones |
| `vault_human/` | Starting skeleton and templates for the human vault |
| `docs/` | The contract and the reasoning, including the sample workspace |

`vault_ai/` and `vault_human/` are named generically because a repository has to explain
both sides to a stranger. **They are not names your own folders have to take** — see
[docs/spec.md](docs/spec.md#where-the-vault-sits).

**Three different roots, and confusing them costs you.** The repository root is what you
are reading. The tool root is `tool/`. The vault root is on your own disk and is where the
shim goes — every machine bakes *that* path into its session hook.

## Known limitations

Stated up front, because finding these yourself is worse than being told.

**A folder that is not synced anywhere still installs cleanly.** Nothing here can ask
Windows whether a folder replicates — sync clients are ordinary programs watching ordinary
directories. So the vault location is checked against the shapes of the services it knows
— Google Drive, OneDrive, iCloud Drive, Dropbox, Syncthing, Nextcloud, ownCloud, pCloud,
MEGA, Resilio Sync, Sync.com and Yandex Disk — and `Initialize` **names them** when none
match, rather than saying "a sync service" and leaving you to work out which of your folders
it means. It is a guess and it says it is a guess. If it
is right and you ignore it, everything on that machine still works and **nothing reaches a
second computer**, because there is no second copy of the folder anywhere. `Vault location:`
in the log is the standing answer.

**The session itself does not travel.** This is the one people expect and do not get.

| Crosses over | Does not |
|---|---|
| Rules, skills, agent definitions | The conversation |
| Memory that was **written** during the session | Whatever you were part-way through |
| | What you were about to do next |

Memory sync reads one folder — the runtime's own `projects\<project>\memory`. A session
transcript does not live there and is not copied. So closing the laptop mid-task on Friday
and opening the other machine on Saturday gives you the same environment and none of the
thread: the agent knows how you work, not what you were doing.

**Nothing writes a handoff for you.** If you want the work to continue elsewhere, leave a
note before you stop — `handoff/` for an instruction to the other machine, `projects/` for
state that spans sessions. Both are folders a person fills in. The sync will tell the other
machine a new handoff exists; it will not invent one.

The shipped [`vault_ai/skills/wrapup/`](vault_ai/skills/wrapup/SKILL.md) is that step: ask for it when you
finish, and it writes the memory, the project state, and the handoff if one is needed. It
still has to be asked. A hook cannot do it — the session-end hook fires after every turn,
which is the wrong granularity, and nothing here can summarise a conversation anyway.

**And give the upload a moment.** The sync writes into the vault when a session ends, but
your cloud client still has to send it. Shut the machine down seconds later and the last
thing written may never leave — and nothing warns you, because the log stays on the machine
you walked away from.

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
