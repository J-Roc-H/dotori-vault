# Memory

Memory is what an agent learned about working — including things not yet verified. It is
not knowledge. Knowledge lives in the human vault and a person decides what goes there.

## Folders

The lifecycle field is authoritative. A folder is physical placement, not status.

| Folder | Holds | Written by |
|---|---|---|
| `<runtime>-handoff/` | A mirror of that runtime's local agent memory | the sync script — do not edit by hand |
| `shared/` | Durable memory common to all runtimes, verified | explicit human or agent move |
| `project/` | Reusable memory from one project | explicit move |
| `candidate/` | Not yet known to be worth keeping | explicit move |
| `archive/` | Low use, deliberately not deleted | explicit move |

## The constraint that catches everyone

**Only the mirrored folder is auto-loaded.** An agent runtime loads memory from one flat
local folder. Memory in any other folder is invisible until something explicitly reads it.

So moving a memory into `shared/` or `project/` is not filing it. It is **removing it from
what the agent sees**. Both may be what you want — just know which one you are doing, and
leave a pointer in the entry document when you move something.

Not knowing this produces the worst version of the mistake: "I organized my memory and the
agent got worse", with no obvious connection between the two.

## Do not hand-edit the mirror

The mirrored folder is kept in step with local agent memory by a three-way comparison. Edit
both sides and you get a conflict, which by design stops that file until a human resolves
it. Fix the local copy and let the next sync carry it.

## Index files

- `MEMORY-<machine>.md` — one index per machine.
- **Never create an unnamed shared `MEMORY.md`.** Two machines will overwrite each other
  every session, and the result still looks like a valid index.
- The sync never pulls another machine's index.

## Two questions, two fields

A memory answers two independent questions, and it took a while to notice they were being
crammed into one field:

| Question | Field |
|---|---|
| How much is this worth **to the agent**? | `status` |
| Has it crossed into **what the person knows**? | `promotedTo` |

They do not line up end to end. A durable memory can be promoted and still be durable; a
promoted one does not stop having a lifecycle. Answering both with `status` meant promotion
erased where the memory sat, which is why they are separate now.

## Lifecycle

```
capture -> candidate -> active -> verified -> durable
                            |
                        archived
```

| Status | Means |
|---|---|
| `candidate` | Might be worth keeping, undecided |
| `active` | Currently true and in use |
| `verified` | Confirmed against evidence |
| `durable` | Worth keeping long term |
| `archived` | Low use, kept anyway |

Rules that make the states mean something:

- **Reaching `verified` requires named evidence** — a path, a commit, test output, an
  incident. Inference is not evidence.
- **Nothing is auto-deleted.** `archived` means kept, not removed.
- **Deletions do not propagate.** A memory missing locally is restored from the archive.
  Retiring one should be deliberate.

## Promotion

`promotedTo` holds the path in the human vault where the finding landed. Absent means not
promoted — there is no value to write for "no".

- **A person sets it, never an agent.** It names a destination only a person knows, which
  is also why nothing migrates it for you.
- **It requires evidence too.** [candidates.md](candidates.md) already demands a verified
  finding before anything is promoted, so a promotion claim with an empty `evidence` list
  is counted the same way a bare `verified` is.
- **The route is [candidates.md](candidates.md)**, not a status change: a finding goes to
  `candidates/`, a person approves it, it lands in the human vault, and only then does
  `promotedTo` get written.

**`status: promoted` is the old spelling.** It still gets evidence-checked, and the log
lists it under *Legacy promoted status* until you migrate it — see
[upgrading.md](upgrading.md).

## Why any of this is counted

Every sync counts statuses, lists entries missing the field, lists entries claiming a
status or a promotion with an empty `evidence` list, and counts promotions. The runtime
enforces none of it, so without the counts these would quietly become metadata nobody
updates. The evidence count in particular was missing for a long time, which left the rule
deciding whether a status means anything as the one rule with nothing watching it — see
[evolution.md](evolution.md) on why that is the same as not having the rule.
