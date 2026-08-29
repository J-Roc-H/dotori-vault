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

## Lifecycle

```
capture -> candidate -> active -> verified -> durable -> promoted
                                     |
                                 archived
```

| Status | Means |
|---|---|
| `candidate` | Might be worth keeping, undecided |
| `active` | Currently true and in use |
| `verified` | Confirmed against evidence |
| `durable` | Worth keeping long term |
| `promoted` | Accepted into human knowledge — **a person sets this, never an agent** |
| `archived` | Low use, kept anyway |

Rules that make the states mean something:

- **Promotion to `verified` requires named evidence** — a path, a commit, test output, an
  incident. Inference is not evidence.
- **Nothing is auto-deleted.** `archived` means kept, not removed.
- **Deletions do not propagate.** A memory missing locally is restored from the archive.
  Retiring one should be deliberate.

Every sync counts statuses and lists entries missing the field. That counter is the whole
reason the convention survives: the runtime does not enforce it, so without a count it
would quietly become metadata nobody updates.
