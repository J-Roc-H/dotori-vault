# Machines and runtimes

The point of this vault is that the environment is the same everywhere. Two dimensions
scale independently, and neither is a list somebody has to maintain.

## Machines

A machine is identified by the computer name. Everything machine-specific is named from
that key rather than enumerated:

| Artifact | Name |
|---|---|
| Manifest | `sync\sync-manifest-<machine>.json` |
| Log | `sync\sync-log-<machine>.md` |
| Memory index | `memory\claude-handoff\MEMORY-<machine>.md` |

There is no machine count and no machine list anywhere in the code. Adding a machine is:
install, run the sync once, done.

Override it with `-MachineKey` if the computer names are not distinct.

### Why not the account name

It was, until recently. An account name identifies a person, not a machine, so two machines
signed in as the same account -- the same person's work and home PC, two boxes both using
`user`, or one cloud account deriving the same local profile on both -- shared one manifest,
one log, and one memory index. That is exactly the failure the rest of this page describes,
reintroduced by the naming scheme meant to prevent it, and it reported no error.

Because any key can collide, the key is not trusted on its own. Each installation generates
a value unique to itself, kept in the local working area and never synced, and records it in
the manifest. If the manifest under this machine's key carries someone else's value, the run
stops and says so rather than adopting a baseline that belongs to another machine.

### Why each machine gets its own manifest and log

These files are rewritten on every session start and every session stop. With one shared
copy in a cloud-synced folder, the losing writer's version comes back as a conflict copy.
In one recorded case that produced 64 stray files in 19 hours.

The manifest is also per-machine *data*, not merely a per-machine file: it records the
hash of this machine's local copy of each memory. One shared copy let whichever machine
synced last overwrite everyone else's baseline.

A missing manifest is safe, not destructive. Without a baseline, every three-way compare
falls through to "both sides changed" and reports a conflict instead of overwriting.

### Why each machine gets its own memory index

The index is the list of what this machine knows. A single shared `MEMORY.md` would be
overwritten by whichever machine synced last, silently discarding the other's view.

Never create an unnamed shared index. Two machines will overwrite each other every
session, and because the file still looks plausible afterwards, nobody notices.

## The sync service underneath

Nothing here talks to a cloud API. The whole tool reads and writes files in a folder, so
**any service that gives you a folder on both machines works** — point `-VaultRoot` at it.

What differs between services is not whether they work, but how they misbehave. When two
machines write the same file, none of them merge: they keep one and rename the other. Each
one names that differently.

| Service | Renames the losing copy to |
|---|---|
| iCloud Drive | `name 2.ext` |
| Google Drive, and several Windows clients | `name(1).ext` |
| Dropbox | `name (conflicted copy MACHINE 2026-01-01).ext` |
| OneDrive | `name-MACHINE.ext` |
| Syncthing | `name.ext.sync-conflict-20260101-120000-ABCDEFG` |

**This table is reported, not verified.** These conventions were collected from
documentation and from what turned up in practice; only one service has actually been run
against long-term. Rather than pretend otherwise, the sync looks for the *shapes* above
after every run and reports what it finds:

```
Cloud conflict copies: 0
```

Above zero, the log lists the paths. One file in each pair contains work that never made it
across, so they are reported and never deleted automatically — only a person can say which
side matters.

The two number-suffix shapes are ambiguous, since `Chapter 2.md` is an ordinary filename.
Those count only when the original sits beside them, which is what makes a copy a copy.

If your service leaves something this does not recognize, that is worth an issue: the shape
is easy to add, and the detection is the part that does not depend on anyone owning a
subscription to every service.

### What a service should not do to you

Two behaviours cause real damage regardless of brand:

**On-demand placeholders.** Services that keep a file "in the cloud" until opened will hand
a program a zero-byte stub. A derived database once sat in the synced folder this way: it
looked present and was actually dead. Keep derived data out of the synced folder entirely —
see [index.md](index.md).

**Locking during write.** Writing a file in place while the client holds it can truncate it
to nothing. Every write here goes to a temporary file and is renamed over the target.

## Runtimes

A runtime is an AI agent installation on a machine. Runtimes differ in what they can
consume, so coverage is per-runtime and the log says so explicitly:

```
Runtimes: agent-a agents=5 skills=14 | agent-b agents=5 skills=14 | agent-c agents=n/a skills=14
```

Two rules keep this honest:

**A missing runtime is not a failure.** The sync runs at every session start. It must
never take the session down because one runtime is not installed on this machine. Absent
runtimes are skipped with a warning.

**Do not publish to a path you have not verified is read.** In the example above one
runtime shows `agents=n/a`. Its documented conventions cover skills but say nothing about
agent definitions, so nothing is written there. An invented path that no runtime reads is
worse than an obvious gap: it looks like coverage.

## What gets published outward

| Asset | Direction |
|---|---|
| Agents | shared source to every runtime that has a documented agent format |
| Skills | shared source to every runtime |
| Rules | shared source to each runtime's expected rules file |
| Memory | **both directions** — see [sync.md](sync.md) |

Memory is the only asset that flows back. Everything else has a single source of truth in
the shared vault, so a local edit to a published copy will be overwritten on the next run.
Edit the source, not the copy.
