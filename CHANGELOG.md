# Changelog

Dates are omitted deliberately: this is extracted from a working setup, and the internal
history contains private material. What is preserved is the order and the reason.

## Unreleased

First public extraction. Nothing has been released yet.

### Fixed after the first public review

Five faults found by reading the published tree as a stranger would, rather than as the
person who wrote it. Every one of them is invisible on the machine it grew up on.

- **The machine key was the account name.** `docs/spec.md` requires a key that is stable
  across runs *and distinct between machines*; an account name gives only the first. Two
  machines signed in as the same account shared one manifest, one log and one memory
  index — the failure per-machine naming exists to prevent, reintroduced by the naming
  scheme itself, reporting nothing while it happened. The key now comes from the computer
  name, `-MachineKey` overrides it, and because any key can collide, each installation
  writes a fingerprint into its manifest and refuses to run when it finds someone else's.
  Files under the old key are copied to the new name, never moved: deletions are not
  propagated, and another machine may still be reading them.
- **The atomic write was not atomic.** `docs/multi-machine.md` promised every write went
  to a temporary file and was renamed over the target. The code called `[IO.File]::Copy`,
  which opens the destination and rewrites it in place — precisely the write the temporary
  file existed to avoid. It is now `Replace` over an existing file and `Move` over a new
  one, with a loud warning if the filesystem supports neither.
- **Session hooks were reinstalled on every run.** The installer sat outside the mode
  check, so `Sync` — which the `Stop` hook fires after *every turn*, not once per session —
  re-entered it and rewrote the runtime's `settings.json` continuously through a
  PowerShell 5.1 JSON round trip that is not lossless. Hooks are now written only by
  `Initialize`, and the writer compares before writing.
- **The agent converter only understood one YAML style.** It matched `description: >` and
  nothing else. Every agent in the setup it was extracted from is written that way, so it
  never surfaced there — but the example agent shipped in `examples/` is a plain scalar,
  so the repository's own sample data converted to `description = ""` with no warning, and
  `tools:` was dropped entirely, sending a read-only agent to another runtime
  unrestricted. Both are fixed, and a missing description now warns instead of shipping an
  agent nothing can select.
- **The implementation defaulted to `Initialize`.** The shim defaulted to `Sync`; running
  the implementation directly with no arguments took the destructive path. Both now
  default to `Sync`. The shim was also missing `-VaultGitOrigin`, which meant the
  parameter documented for bootstrapping a second machine could not be passed through the
  entry point the install instructions name.

### Changed

- **The headline promised the wrong thing.** It said you could carry on at home the *work*
  you were doing at the office. What actually travels is the *environment* — rules, skills,
  agent definitions, and memory that was written down. The conversation does not: memory
  sync reads the runtime's `projects\<project>\memory` folder, and a session transcript is
  not in it. So a person could close the laptop mid-task believing DOTORI had them covered,
  and find the same setup and none of the thread waiting at home. The tagline now says
  environment, and `Known limitations` opens with what crosses and what does not, why, and
  the fact that nothing writes a handoff for you — plus the quieter trap that the cloud
  client still needs time to upload after the last session ends, and the log that would
  have told you stays on the machine you walked away from. `docs/handoff.md` says the same
  in one line where a reader will hit it: that folder is written by a person.
- **This repository is now the code, not an extract of it.** It was published as a scrubbed
  subset of a private setup that its author kept running separately — which meant the
  published version was the one nobody actually used, and every fault above is of exactly
  that kind: real on a fresh machine, invisible on the one it grew up on. The script here
  is now the script its author runs. A vault still holds private content; the code does not
  live there. The publish gate that screened the old extraction step is gone with the step,
  and README no longer refers to it as though it protects anyone.
- **`brain-git.ps1` is usable by someone other than its author.** Both paths were
  hardcoded, the vault path pointing at one particular iCloud folder with no way to
  redirect it, so the file was dead weight in a public repository. Now `-VaultRoot` and
  `-MirrorRoot`, defaulting to the same values the sync script uses. Its
  `$Args` parameter, which shadowed the automatic variable of that name, is now `$GitArgs`.
  It is also listed in the README, which it never was.

### Added

- **The documented install is now executed, not just described.** Everything in `tests/`
  exercised the implementation with paths pointed at a scratch tree, which left two things
  nothing had ever run: the shim at the vault root — the entry point the instructions name,
  and the path every session hook is baked with — and hook installation into a
  `settings.json` that actually exists. The conformance tests have no settings file on
  purpose, so they covered the skip path and not the writing path, which is the one that
  edits a file the user depends on. `tests/Install.Tests.ps1` follows the README steps
  literally on a clean runner and checks that the hooks land, point at the shim rather than
  the implementation, leave unrelated settings alone, get backed up first, and that a second
  run reports nothing to do. README said the install "has not been run on a genuinely fresh
  Windows install"; now it runs on one every commit. That still does not replace a person
  following the words — a test cannot tell whether an instruction was confusing.
- **`docs/upgrading.md`** — what an existing installation has to do, which nothing described.
  The documents covered the first run and not the second version: same shape of gap as the
  rest of this audit. It walks the machine-key migration (copies, never moves, and the stale
  copies are deleted by hand only after every machine has run once), says the existing hooks
  need nothing, and warns that the three new counters will not read zero on an established
  vault — a first upgrade surfacing a backlog is the counters working, not the upgrade
  failing.
- **Issue templates**, which `CONTRIBUTING.md` described and the repository did not have —
  the same defect this project keeps finding in itself. The two that matter most are the
  fresh-install report and the sync-service conflict-copy shape: both ask for knowledge that
  cannot be obtained from here, which is what makes them worth someone's time.
- **`skills/wrapup/`, and two counters that make it checkable.** This project's own rule is
  that a convention nobody counts is already broken. Auditing the documents against that
  rule found the reverse problem as well: several conventions had **no act** — the folders
  and the counters shipped, and nothing that fills them did. Memory has a lifecycle nobody
  writes, `handoff/` is an inbox nothing posts to, `projects/` holds state nothing records.
  The author had private skills for all of it and so never felt the gap; a new installation
  gets the audit without the means.

  `skills/wrapup/` is that act, kept to exactly what Core already defines: write the memory
  with the required fields, update project state if the work spans sessions, write a handoff
  if it must continue elsewhere. It never promotes, never deletes, and never fires by
  itself. It is generic on purpose — a wrapup that knows your document standard or your
  vault layout is domain content and belongs in your own repository, which `CONTRIBUTING.md`
  now states as the limit of this exception.

  Two conventions that had no counter now have one:
  - **`verified` with an empty `evidence` list is counted and named.** `docs/memory.md` and
    `docs/spec.md` both require named evidence and say inference is not evidence. Nothing
    checked it, so the rule that decides whether a status means anything was the only rule
    with nothing watching it.
  - **Handoffs older than `-StaleHandoffDays` (14) are counted and named.**
    `docs/handoff.md` already described this failure exactly — a pile of finished-but-present
    handoffs makes the whole list untrustworthy — while the log watched only for arrivals.

  The remaining five from that audit are now resolved, and only two of them by writing
  code — which was the point. A convention earns a counter when its drift is silent,
  harmful and *unambiguous*; if it cannot be counted without guessing, the convention is
  underspecified or should not exist. Building all five would have grown the system to
  satisfy its own documentation. `docs/evolution.md` now carries that rule beside the one
  it qualifies.

  - **`candidates/` waiting too long is counted and named.** The folder has four criteria
    and a human approval gate, and nothing read it at all — a queue whose entire purpose is
    review, unable to say it was not being reviewed.
  - **Each rules file's line count is reported.** `docs/routing.md` budgets the router at
    roughly 30 lines because every task pays to read it, then measured nothing. Reported,
    never failed: "roughly" is the document's word, and a build that fails on line 31 of a
    soft budget is a check nobody keeps.
  - **Removed: the entry document's duplicate handoff list.** `docs/handoff.md` asked for a
    hand-maintained list of open handoffs while `docs/routing.md` says to give every fact
    exactly one owner, because two will disagree and nothing will say which is current. The
    log now reports what is new and what is stale, so the duplicate has no reason to exist.
    The check nobody should build here is the one that parses free-form prose to find a
    list — it would guess, and a check that cries wolf gets ignored.
  - **Removed: the promise that something reports a stale inbox.**
    `human-vault/structure.md` called an unprocessed item past thirty days "worth
    reporting", implying a reporter that does not and should not exist: the sync does not
    read the human vault, and a tool that walked through it to count things would be
    reaching into the wrong half of the split the structure exists to keep.
  - **Not done: staleness for the vault's `projects/`.** Nothing here can tell a long-running
    project from an abandoned one, and age is a bad proxy for either. A counter with no
    honest signal behind it is worse than the gap.

- **`-Mode Report`** — a pre-flight that writes nothing. It resolves every path, says which
  runtimes it found, and names the settings files it would edit along with the exact hook
  line it would add. Everything it prints is derived from the same variables the real run
  uses, so it cannot describe one thing and do another, and a test lists the entire tree
  before and after to confirm it leaves nothing behind — including the machine identity
  file, which a report that created it would have quietly turned into "already installed".
  This is the first thing the install instructions now tell you to run: the tool's opening
  move is editing the config of the agent you depend on daily, and until now there was no
  way to look first.
- **An uninstall section in the README.** Three steps, one of which is "keep your vault, it
  is plain Markdown". Reversibility was true the whole time and written down nowhere.
- **[docs/quickstart.md](docs/quickstart.md)** — ten minutes on a scratch path. It builds
  two machines in a temp folder and walks through publication, cross-machine memory, a real
  conflict refusing to merge, and the key-collision guard, then deletes the lot. It is not a
  special demo mode: every path is a parameter, so this is the ordinary install aimed
  somewhere disposable. Previously the only way to find out whether this worked for you was
  to install it on the machine you actually care about.
- `CONTRIBUTING.md` — what the project takes (mechanism, not domain content), the two
  reports worth the most, and a plain statement of how much maintenance to expect. Also
  what happens to your data if the project stops, which is the question a one-maintainer
  project owes an answer to.
- `tests/Conformance.Tests.ps1` — the conformance check from `docs/spec.md` section 10,
  executed instead of described. It builds two machines in a temp tree (one shared vault, a
  separate runtime home and mirror each) and runs the implementation end to end against
  every point: idempotence, propagation, real conflicts leaving both sides untouched,
  encoding-only differences converging without a conflict, per-machine files never written
  by the other machine, and a forced key collision stopping the run. Also covers invariant
  2 (deletions restored, not propagated), invariant 6 (a missing runtime is skipped, not
  fatal), and the agent conversion end to end. The spec was precise enough to test; this is
  what makes it a contract rather than a description.
- `tests/` — regression tests pinning each of the above, plus a check that the shim and the
  implementation expose the same parameters. Not yet the conformance harness that
  `docs/spec.md` section 10 describes; that is the next step.
- `.github/workflows/ci.yml` — runs those tests on `windows-latest`, lints with
  PSScriptAnalyzer, and fails the build on any non-ASCII byte in a `.ps1` file. The
  ASCII rule was previously an intention; it is now a check.

### The architecture at this point

- Two vaults: one for human knowledge, one for agent operating state
- Machine identity derived from the account running the sync, so machine count is not a
  fixed value anywhere in the code
- Agents, skills and rules published outward to each installed runtime; missing runtimes
  skipped with a warning rather than an error
- Memory synced in both directions with a three-way comparison, stopping on genuine
  conflicts and resolving encoding-only ones
- Per-machine manifest, log and memory index
- Git history kept outside the cloud-synced vault
- Publication through an allowlist with a fail-closed scrub gate

### Fixed on the way to extraction

- **Memory sync could freeze permanently.** A byte-order mark or a few stray carriage
  returns made both sides look edited, which reported a conflict, and a conflict keeps its
  previous baseline by design — so nothing self-healed. Content is now compared with those
  discounted before a conflict is declared.
- **The publish gate had a hardcoded machine name.** A machine not in that hand-written
  list would be neither scrubbed nor caught by the assertion meant to prove the scrub
  fired. Machine identities are now discovered, each generating a scrub rule and its
  matching assertion, with a catch-all for anything still shaped like an unaccounted-for
  machine name.
- **`Skills synced: N` was a file count read as a skill count.** A specification was once
  written against the misreading. The label now names its unit — and once it did, the gap
  between the two numbers turned out to be two stale editor copies that had been quietly
  published into every runtime, each declaring the same skill name as the file beside it.
  Labelling the unit is what made them visible.
- **Per-runtime coverage was invisible.** One aggregate number hid a runtime receiving
  nothing. The log now reports each runtime separately.
- **Published docs were scrubbed private documents.** They came out in the wrong language
  and carried links to documents that do not exist publicly. All prose here is now written
  for publication.

### Found by the first clean-install rehearsal

The install had never been run as written — only by hand, onto machines that already had a
working setup. Rehearsing it into an empty directory tree found three faults, each of which
is invisible on a machine that is already configured:

- **Initialize copied the script onto itself and died.** Following the documented steps
  puts the running script at the install target, and `Copy-Item` refuses that, so the
  install failed at its last step with exit code 1. The Sync path had guarded against it
  for as long as it existed; Initialize never had.
- **A hardcoded repository URL** made every install anywhere adopt one particular private
  repository as its git origin and fetch from it. Now a parameter, empty by default, with
  a publish-gate check so no owner-bearing URL can ship again.
- **A missing hook was installed in silence.** With no settings file yet present, the hook
  installer returned without a word: exit code 0, success reported, nothing installed —
  against documentation promising it would run every session from then on.

The rehearsal was only possible after making the Antigravity rules path a parameter. It
was the one write no parameter could redirect, so any rehearsal would have overwritten the
real file.

See [docs/evolution.md](docs/evolution.md) for the structures that preceded this one and
what each of them failed at.
