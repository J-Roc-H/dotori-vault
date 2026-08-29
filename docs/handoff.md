# Handoff

A work order for a specific machine. Some work can only be done where a particular tool,
account, or file lives; a handoff is how the machine that cannot do it tells the one that
can.

Handoffs travel with the vault's own cloud sync. They are not part of the memory sync.

**Nothing creates a handoff for you.** This folder is written by a person. The sync reads
it, notices files it has not seen before, and says so in the log — that is all it does. A
session that ends without one leaves nothing behind for the other machine, however much
work went into it.

File name: `handoff-<machine>-<topic>-<date>.md`

## Not the same as memory

| | `handoff/` | `memory/<runtime>-handoff/` |
|---|---|---|
| Content | what needs doing | what was learned |
| Lifetime | **deleted** once done and verified | kept, with a lifecycle |
| Sync | vault sync only | three-way comparison |

**Do not put work orders in the memory folder.** That folder is paired by filename against
each machine's local agent memory, so a work order dropped there gets copied into every
machine's memory as though it were something learned.

The name collision between the two is unfortunate and worth knowing about: one is *a
handoff*, the other is *the folder mirroring a runtime's memory*.

## Rules

- Read the relevant handoff **before** starting work in that area
- **Delete the file** once the work is done and verified — deleting is the completion
  signal, not a checkbox inside it
- The entry document owns the list of open handoffs; update it when you add or remove one

A handoff that is marked done but left in place stops meaning anything. If several are
sitting there completed, nobody trusts the list, and the next real one gets ignored too.

So the sync counts how many have been sitting longer than a threshold (`-StaleHandoffDays`,
14 by default) and names them. Reporting only *new* handoffs, which is what it used to do,
watches for the arrival and not for the pile.

## Minimum contents

- What changed
- What evidence was checked
- What is **not** verified
- Known problems
- Recommended starting point
- Date and paths

The "not verified" section is the one that earns its keep. Without it the receiving side
cannot tell what was tested from what merely looked finished.
