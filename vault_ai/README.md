# The AI vault

The other half of DOTORI. This is what agents need in order to work; the human vault holds
what a person knows.

For which side a given thing belongs on, see [../vault_human/README.md](../vault_human/README.md) —
the boundary is written up once, there, rather than twice.

## What is published here

Only `skills/wrapup/`. Everything else in an AI vault is either yours or generated:

| Folder | Where it comes from |
|---|---|
| `skills/` | Yours. `skills/wrapup/` ships as a starting point — replace it if you have your own |
| `agents/`, `source/` | Yours |
| `memory/`, `handoff/`, `projects/`, `candidates/` | Written as you work |
| `sync/` | Written by the sync, per machine |

**They are not in this repository because they would be empty.** Git does not track empty
folders, and a folder full of placeholder files is worse than no folder: it looks like
content. `-Mode Initialize` creates the whole tree on first run.

The full layout, with what each folder is for, is [../docs/spec.md](../docs/spec.md) section 2.

## This is not your vault root

Your vault lives on your own disk, in a folder your sync service carries between machines.
This directory is the starting content you copy into it — see the Install section of
[../README.md](../README.md).

**Nor is `vault_ai` a name your folder has to take.** It is named that here because a
repository has to explain the two sides to a stranger. Yours can be called anything; the
script is pointed at it with `-VaultRoot` and never looks at what it is called.

The distinction matters more than it sounds. The shim at *your* vault root is the path
every machine bakes into its session hook, and a machine whose hook points at nothing can
never run the sync that would deliver the fix.
