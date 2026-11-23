# DOTORI Vault

**A Windows workspace that keeps one Markdown-based AI setup across your machines
without requiring a Git remote.**

DOTORI gives Claude Code and Codex one source for skills and agent definitions, and
publishes them to the formats each runtime expects. It also keeps the shared vault
plain Markdown, keeps its local Git metadata *outside* the cloud-synced folder, and
stops on a real memory conflict instead of silently picking a winner.

No API. No database. No service. No daemon. No `.git` directory inside the synced vault.

[Try the safe 10-minute demo](docs/quickstart.md) ·
[Read the installation steps](#install-on-your-own-machine) ·
[Report a try or install](https://github.com/J-Roc-H/dotori-vault/issues/new?template=try-dotori.yml)

> **Windows and PowerShell 5.1 are required for the shipped implementation.**
> The vault format is documented separately, so another implementation can share it.

## Is DOTORI the right tool?

Choose DOTORI when all of these describe your setup:

- You use **Windows** and at least one of Claude Code or Codex.
- You want one Markdown source for shared skills and agent definitions on more than one
  runtime or machine.
- Your machines already have an **allowed, synced folder** (for example OneDrive,
  Dropbox, iCloud Drive, Google Drive, Syncthing, or another service that exposes a
  folder on both devices).
- You cannot, do not want to, or are not permitted to make a Git remote the path between
  those machines.
- You prefer conflicts to stop for a human decision over automatic merging or
  last-writer-wins.

Choose [skillshare](https://github.com/runkids/skillshare) instead when you need broad
cross-platform runtime support, team distribution through Git repositories, MCP/plugin
management, a desktop interface, or its built-in skill audit. It supports far more agent
tools than DOTORI does and is the better general-purpose choice.

| Question | DOTORI | skillshare |
|---|---|---|
| Primary transport between machines | A folder you already sync | Git-managed source and pull/clone workflow |
| Shipped platform | Windows PowerShell 5.1 | Windows, macOS, Linux |
| Runtime coverage | Claude Code, Codex, selected Antigravity paths | Broad multi-tool coverage |
| Shared source | Plain Markdown vault | Managed configuration/source directory |
| Memory position | Conservative native-store reconciliation; real conflicts stop | Its README focuses on skills/resources rather than a DOTORI-style native-memory sync claim |
| Best fit | A Windows personal setup with an approved synced folder and no required Git remote | Most multi-tool, team, or Git-based setups |

This is a difference in constraints, not a security workaround. If one machine belongs to
an employer, both the synced folder and every file placed in it must comply with that
organization's policy. DOTORI does not inspect, filter, or authorize content for you.

## What it shares, and what it does not

~~~
                     shared Markdown vault
          agents  ·  skills  ·  explicit rule sources
                              |
              +---------------+----------------+
              |                                |
         Claude Code                         Codex
     Markdown agents/skills          TOML agents/skills
              |                                |
              +---------- synced folder -------+
                         work / home machines
~~~

| Asset | Current behavior |
|---|---|
| Skills | One shared Markdown source publishes to Claude Code, Codex, and Antigravity's verified workspace skill path. |
| Agent definitions | Claude Markdown definitions are the source; DOTORI converts them to Codex TOML. Antigravity has no verified agent-definition convention, so DOTORI deliberately does not invent one. |
| Rules | Opt-in sources can publish to Codex `AGENTS.md` and Antigravity `GEMINI.md`; existing local rules are otherwise left alone. |
| Claude memory | The selected primary Claude memory store is reconciled between machines with a three-way comparison. |
| Codex memory | The native Markdown tree is preserved in a machine-scoped archive. DOTORI does **not** claim it becomes portable cross-runtime context. |

DOTORI does **not** sync conversation transcripts, resume an unfinished session, decide which
memory an agent should inject into context, or automatically merge a real conflict. It
keeps the environment and written state available; it does not make one agent's live
conversation magically continue in another.

For the exact store boundaries, see [docs/memory.md](docs/memory.md) and
[docs/multi-machine.md](docs/multi-machine.md).

## See it safely before installing

The [quickstart](docs/quickstart.md) builds disposable runtime folders under your temporary
directory. It demonstrates, in roughly ten minutes:

1. `-Mode Report` resolving paths without writing anything.
2. A Markdown Claude agent becoming a Codex TOML agent.
3. A second machine receiving the shared state.
4. A deliberate memory conflict stopping without either version being overwritten.

Nothing in that walkthrough touches a real vault, runtime settings file, or runtime
directory. Every path is redirected explicitly.

## Install on your own machine

Install Claude Code, Codex, or both first. DOTORI will not fabricate their settings files,
because creating a configuration a runtime has never written is unsafe.

**1. Inspect the exact targets first.** This mode is read-only.

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<repo>\tool\sync-ai-shared.ps1" `
  -Mode Report -VaultRoot "D:\my-synced-folder\dotori-vault"
~~~

It reports the resolved vault, installed runtimes, settings files it would edit, and the
exact session hook command it would add.

**2. Copy the runtime files into the vault.**

- `tool\sync-ai-shared.ps1` → `<vault>\sync-ai-shared.ps1`
- `tool\scripts\sync-ai-shared.ps1` → `<vault>\scripts\sync-ai-shared.ps1`
- `vault_ai\skills\wrapup\` → `<vault>\skills\wrapup\`

The root shim must remain at that path: installed session hooks call it.

**3. Initialize deliberately.**

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<vault>\sync-ai-shared.ps1" `
  -Mode Initialize -VaultRoot "D:\my-synced-folder\dotori-vault"
~~~

`Initialize` seeds the vault and adds session hooks only to settings files that already
exist. It warns when the vault path does not resemble a known sync folder; that detection is
a hint, not proof. `Sync` is the default hook mode and does not reinstall hooks every run.

The full disposable walkthrough, including the expected output and a conflict example, is
[docs/quickstart.md](docs/quickstart.md). Existing users should read
[docs/upgrading.md](docs/upgrading.md).

## How synchronization stays recoverable

- A local Git mirror can record vault history, but its `.git` directory stays outside the
  cloud-synced vault. A Git remote is optional and never added unless you pass one.
- Each machine owns its own manifest, log, and memory index. A collision in the machine
  identity stops the run instead of silently sharing a baseline.
- Memory uses a baseline/local/shared three-way comparison. If both sides changed but are
  textually identical after BOM and line-ending normalization, it converges them; otherwise
  it leaves both copies untouched and logs the conflict.
- Deletions do not propagate automatically. A missing local memory is restored from the
  archive so that a sync cannot quietly erase it.
- The log calls out conflict copies created by known cloud clients, but never deletes them.

Read [docs/sync.md](docs/sync.md) for the comparison rules and
[docs/spec.md](docs/spec.md) for the on-disk contract.

## Important limits and safety

- A folder that is not actually synced still works on one machine and reaches no second
  machine. DOTORI cannot verify replication from Windows.
- The script reads runtime-internal memory locations whose layouts can change without
  notice. Check `Memory source:` in the generated log.
- The installation writes session hooks into existing runtime settings files. Use
  `-Mode Report` first and read the target paths.
- Keep credentials, runtime settings, plugin caches, session logs, and employer-specific
  information out of the shared vault unless your policy explicitly permits them there.
- A missing runtime is skipped with a warning; a real memory conflict requires a human
  decision.

For a clean-Windows rehearsal, including the behavior without Git or an installed runtime,
see [docs/fresh-machine-check.md](docs/fresh-machine-check.md).

## Feedback that helps

DOTORI is a personal setup made public for people with this particular constraint. The most
useful reports are:

- A [safe try/install report](https://github.com/J-Roc-H/dotori-vault/issues/new?template=try-dotori.yml):
  what you tried, where the first confusing step was, and whether the scratch demo or an
  actual setup completed.
- A [fresh-Windows report](https://github.com/J-Roc-H/dotori-vault/issues/new?template=fresh-install-report.yml):
  especially a result from a machine that started without a working setup.
- A [sync-service conflict-copy shape](https://github.com/J-Roc-H/dotori-vault/issues/new?template=sync-service-report.yml)
  that the log did not recognize.

Do not paste vault contents, credentials, employer data, runtime settings, or an unredacted
sync log. A redacted summary and the relevant warning or error lines are enough to begin.

## Documentation

| Document | Start here when you need… |
|---|---|
| [docs/quickstart.md](docs/quickstart.md) | A disposable, copy-pasteable demonstration |
| [docs/upgrading.md](docs/upgrading.md) | To update an existing installation |
| [docs/spec.md](docs/spec.md) | The portable on-disk contract |
| [docs/multi-machine.md](docs/multi-machine.md) | Machine identity, runtime coverage, and sync-folder behavior |
| [docs/sync.md](docs/sync.md) | Three-way reconciliation and conflict handling |
| [docs/memory.md](docs/memory.md) | Native-store boundaries and the evidence lifecycle |
| [docs/evolution.md](docs/evolution.md) | The failures that shaped the design |
| [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) | What contributions are in scope |

## License

[MIT](LICENSE)
