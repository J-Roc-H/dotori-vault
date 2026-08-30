# The on-disk contract

DOTORI is a layout and a set of rules. The PowerShell script in this repository is one
implementation of them, not the definition.

This document is what you would need to write another one — on another platform, in
another language — that could share a vault with this one without either side noticing.

Everything here is plain UTF-8 text and JSON. There is no service, no database, and no
wire protocol; two implementations interoperate by agreeing on files.

---

## 1. What an implementation must do

Four jobs, in this order:

1. **Adopt** — take changes an operator made in a runtime's own config and bring them into
   the shared vault
2. **Publish** — write the vault's agents, skills and rules outward into each installed
   runtime
3. **Reconcile memory** — a three-way comparison in both directions
4. **Record** — write this machine's manifest and log

An implementation that does only 2 and 4 is still useful and still conformant, as long as
it does not corrupt what 1 and 3 would need. Say so in its documentation.

---

## 2. Shared vault layout

```
<vault>/
+-- <entry document>            operating guide, owns the open-handoff list
+-- <rules document>            memory schema and operating rules
+-- sync-<name>.ps1             the shim a session hook calls (implementation-specific)
|
+-- agents/                     agent definitions, one file each
+-- skills/<skill>/SKILL.md     one folder per skill, SKILL.md required
+-- source/                     per-runtime global rules files
|
+-- memory/
|   +-- <runtime>-handoff/      mirror of that runtime's local memory. Machine-written
|   +-- shared/                 durable memory, moved here deliberately
|   +-- project/                per-project reusable memory
|   +-- candidate/              undecided
|   +-- archive/                low use, kept
|
+-- handoff/                    machine-to-machine work orders
+-- projects/                   agent working context
+-- candidates/                 promotion candidates for the human vault
+-- sync/                       manifests and logs, per machine
```

Folder names above are the contract. Anything else in the vault is ignored.

### Where the vault sits

**The contract says nothing about what your folders are called.** An implementation is
pointed at the vault directly, and must not require a sibling to exist, must not read one,
and must not create one. What follows is a shape, not a set of names.

The vault is normally one of two folders under a single synced workspace:

```
<workspace>/                    the folder your sync service carries between machines
+-- <your ai vault>/            the vault this document specifies
+-- <your human vault>/         what a person knows. Not specified here
```

Two folders rather than one because they answer to different owners: agents write into the
first constantly, a person writes into the second deliberately, and a promotion from one to
the other is supposed to feel like a decision. Sharing a root would make it feel like a
move.

**Call them whatever you already call them.** This repository names its own starting
skeletons `vault_ai/` and `vault_human/` because a repository has to explain the two sides
to a stranger, and needs generic words to do it. Your own vault is not a stranger's, and a
name that means something to you is a better name — `VAULT_AI` and `VAULT_JROC` are as
conformant as anything here. An implementation that behaves differently based on the folder
name is not conformant.

---

## 3. Machine identity

A machine key is a short stable string identifying one machine. Any implementation may
choose its own source **as long as it is stable across runs on that machine and distinct
between machines.**

**Do not use the account name.** This implementation did, and it satisfies only the first
half of that rule: an account name identifies a person, not a machine. Two machines signed
in as the same account -- one person's work and home PC, two boxes both using `user` or
`Administrator`, or one cloud account deriving the same local profile on both -- collapse
onto a single set of filenames and overwrite each other's baseline, which is the failure
this section exists to prevent. This implementation now derives the key from the computer
name.

**Stability and distinctness cannot be assumed; the second half must be checked.** Any key
source can collide. An implementation must write, alongside the manifest, a value unique to
that installation, and must compare it on every run:

Three files are named from it. There is no machine registry and no machine count anywhere:

| File | Path |
|---|---|
| Manifest | `sync/sync-manifest-<machine>.json` |
| Log | `sync/sync-log-<machine>.md` |
| Memory index | `memory/<runtime>-handoff/MEMORY-<machine>.md` |

**Required behaviour:** never read another machine's manifest, and never pull another
machine's index. Both are that machine's private view; adopting either silently destroys
its state.

**Required behaviour:** on reading a manifest under this machine's key, compare the
recorded installation fingerprint with this installation's own. If they differ, two
machines share a key: **stop with an error.** Do not adopt the baseline, and do not
silently pick a new key -- the operator has to decide. A collision that only produces
conflict copies is survivable; a collision that is adopted as a baseline mis-reconciles
memory.

**Why per machine at all:** these files are rewritten on every session start and stop.
One shared copy in a cloud-synced folder produces conflict copies — in a recorded case,
64 within 19 hours — and a shared manifest lets the last writer overwrite everyone's
baseline.

---

## 4. Manifest

`sync/sync-manifest-<machine>.json`, UTF-8, no BOM required.

```json
{
  "schema": 2,
  "updated": "2026-01-20T14:31:02.1234567+09:00",
  "source": "<absolute path to the vault>",
  "machine": "<machine key>",
  "machineFingerprint": "<value unique to this installation>",
  "files": [
    {
      "relative": "agents\\example-reviewer.md",
      "shared":   "<SHA256 hex, uppercase>",
      "<runtime>": "<SHA256 hex, uppercase>"
    }
  ],
  "conflicts": ["memory\\claude-handoff\\some-memory.md"],
  "handoffSeen": { "<machine>": ["handoff-....md"] }
}
```

| Field | Meaning |
|---|---|
| `schema` | Currently `2`. An implementation reading a lower number must migrate, not fail |
| `machine` | The key this manifest is named from. Informational |
| `machineFingerprint` | Unique to the installation that wrote it. Generated once, kept **outside** the vault, never synced. A different value under the same key means two machines share that key |
| `files[].relative` | Path from the vault root. **Backslash-separated on Windows** — an implementation on another separator must normalize on read and write |
| `files[].shared` | Hash of the vault's copy at the end of the last run |
| `files[].<runtime>` | Hash of that runtime's published copy. Key name is the runtime's id |
| `conflicts` | Unresolved paths. Informational; the per-file baseline is what enforces them |
| `handoffSeen` | Per machine, the handoff filenames it has already reported as new |

**A missing manifest must be safe.** Without a baseline every comparison falls through to
"both sides changed", which reports a conflict rather than overwriting. An implementation
must never treat a missing manifest as permission to publish over local state.

---

## 5. Memory

### Frontmatter

```yaml
---
name: <kebab-case-slug>
description: <one line, used to judge relevance during recall>
metadata:
  node_type: memory
  type: project | feedback | reference | user
  status: capture | candidate | active | verified | durable | archived
  agent: <runtime id>
  evidence: []
  promotedTo: <path in the human vault>    # optional; absent means not promoted
  modified: <ISO 8601>
---
```

`name`, `description` and `metadata` are the required top-level keys; some agent runtimes
enforce exactly those three, so extensions go **inside** `metadata` rather than beside it.

An implementation **must not delete `metadata` fields it does not recognize.** The schema
is a convention, not something a runtime enforces, so the only thing protecting it is
every writer leaving unknown keys alone.

### Lifecycle

How much this memory is worth to the agent that holds it:

```
capture -> candidate -> active -> verified -> durable
                            |
                        archived
```

| Rule | |
|---|---|
| `verified` requires evidence | A path, commit, test output, or incident. Inference is not evidence |
| Nothing is auto-deleted | `archived` means kept |
| Every run counts statuses | And lists entries missing one. Without the count the field dies |

### Promotion

Whether it has crossed into human knowledge. **This is a second axis, not the end of the
first one** — a memory is promoted *and* still sits somewhere in its own lifecycle.

```
memory -> candidates/ -> a person approves -> human vault -> promotedTo = <path>
```

| Rule | |
|---|---|
| `promotedTo` is set by a person | Never by an agent. It names a destination only a person knows |
| Absent means not promoted | There is no "unpromoted" value to write |
| `promotedTo` requires evidence | Promotion criteria already demand a verified finding |
| Every run counts promotions | Same reason as statuses |

Modelling promotion as a status was wrong in a way worth recording: it made promotion
*replace* a memory's lifecycle position, so a durable memory that reached the human vault
stopped being able to say it was durable. The two questions are independent, and one field
cannot answer both.

**`status: promoted` is legacy.** An implementation reading it must keep applying the
evidence rule to it — dropping the check when the value left the enum would exempt exactly
the memories the rule was written for — and should report it as needing migration. Nothing
may rewrite it automatically: the destination path is not derivable.

### Reconciliation

Per file, three values: `baseline` (this machine's manifest), `local`, `shared`.

| local vs baseline | shared vs baseline | Action |
|---|---|---|
| same | same | none |
| changed | same | **push** |
| same | changed | **pull** |
| changed | changed | normalize, then decide (below) |

Present on one side only: **copy, never delete.** Deletions are not propagated in either
direction.

### The normalization rule

When both sides look changed, compare the text again with **a UTF-8 byte-order mark and
all carriage returns removed**. If the results are equal, the difference is an encoding
rewrite, not an edit: converge the bytes and count it separately from conflicts.

**The comparison must not be widened further.** Trailing spaces and blank lines inside a
memory are content; ignoring them would hide a real edit, which defeats the mechanism.

**The raw hash is still what the manifest stores.** Normalization answers "is the text
different"; the manifest answers "did this file change at all". They are different
questions and conflating them loses the ability to detect a rewrite at all.

Without this rule, sync deadlocks. A conflict deliberately keeps its previous baseline, so
a single stray byte-order mark makes every subsequent run reach the same conclusion
forever.

### Real conflicts

Touch neither side. Record the path. Keep the previous baseline so the conflict survives
into the next run rather than being adopted by whichever side is examined first.

**No implementation may auto-merge memory.**

---

## 6. Publication

Agents, skills and rules flow one way: vault to runtime. A local edit to a published copy
is overwritten on the next run.

An implementation declares, per runtime: an id, where agent definitions go, in what
format, where skills go, and where the rules file goes.

Three required behaviours:

**A missing runtime is not an error.** This runs at session start and must never take the
session down because something is not installed. Skip it and warn.

**Do not publish to an unverified path.** If a runtime has no documented convention for an
asset, publish nothing for it and report the gap. An invented path that nothing reads
looks like coverage and is worse than an obvious hole.

**Report coverage per runtime.** One aggregate number hides a runtime receiving nothing.

---

## 7. Log

`sync/sync-log-<machine>.md`. Human-readable; no implementation parses another's log.

```
Agents synced: 5
Runtimes: agent-a agents=5 skills=14 | agent-b agents=5 skills=14 | agent-c agents=n/a skills=14
Skills synced: 14 skill(s) / 14 file(s)
Memory: pushed 3 / pulled 0 / normalized 0 / conflicts 0
Conflicts: 0
Lifecycle: active=80 verified=6 / no-status=0
Promoted: 3 memory(ies) with a human-vault destination
Legacy promoted status: 0 memory(ies) to migrate
```

**Every count names its unit.** A number labelled ambiguously gets read as the wrong
quantity, and then something gets built on the misreading — `Skills synced: 16` was a file
count that a specification once treated as a skill count.

Splitting it into two numbers also makes a whole class of problem visible: when the file
count exceeds the skill count, either a skill legitimately ships extra files or something
is in that folder that should not be. In the case that prompted this, it was the latter.

Conflicts, missing lifecycle fields, and new handoffs are listed by path underneath.

---

## 8. Git

If an implementation keeps history, **the git directory must not live inside the vault.**
Two machines syncing the same `index` and packfiles through a cloud service will corrupt
the repository. Keep the git directory local to each machine and point only the work tree
at the vault.

Exclude from history the files that change every run — manifests, logs, editor workspace
state, and any derived index — so that a commit means content actually changed.

---

## 9. Invariants

An implementation that breaks any of these is not conformant, regardless of what else it
does correctly.

| | |
|---|---|
| 1 | Memory is never auto-merged |
| 2 | Deletions are never propagated |
| 3 | Another machine's manifest or index is never read |
| 4 | Unknown `metadata` fields are never dropped |
| 5 | A derived index is never a source of truth — it must be rebuildable from text alone |
| 6 | A missing runtime never fails the run |
| 7 | The git directory is never inside the vault |
| 8 | A missing manifest never authorizes overwriting local state |
| 9 | A machine key collision is detected and stops the run, never adopted |

---

## 10. Conformance check

Two implementations share a vault correctly if, after each has run twice:

- the second run of each reports no changes (idempotence)
- a single-character edit on one machine appears on the other
- an edit made on both sides is reported as a conflict and neither file is modified
- an encoding-only difference is resolved without reporting a conflict
- neither machine's manifest, log or memory index has been written by the other
- two machines forced onto the same key stop with a collision error rather than
  overwriting each other

This repository executes that check rather than only describing it:
[`tests/Conformance.Tests.ps1`](../tool/tests/Conformance.Tests.ps1) builds two machines in a
temporary tree — one shared vault, a separate runtime home and mirror per machine — and
runs the implementation end to end against each point above. Every path the script touches
is a parameter, which is what makes that possible; an implementation that hardcodes any of
them cannot be conformance-tested, and that is a reason to treat hardcoding as a defect.

A second implementation should be able to take the same list and produce its own harness.
If it can also share a vault with this one and both harnesses stay green, the two
interoperate.
