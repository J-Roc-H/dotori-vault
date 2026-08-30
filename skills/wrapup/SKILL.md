---
name: wrapup
description: >
  End-of-session routine. Run when the user says they are finishing, wrapping up, stopping
  for the day, or switching machines - and before any break long enough that the thread
  would be lost. Records what was learned as memory with the required lifecycle fields,
  updates project state if the work spans sessions, and writes a handoff if it has to
  continue on a different machine. Does not promote to human knowledge and does not delete
  anything; both are a person's decision.
---

# wrapup — finishing a session so the next one can start

Nothing in DOTORI writes this for you. The sync moves what is already on disk; it cannot
summarise a conversation. If a session ends without this step, the environment travels to
your other machine and the thread does not.

This skill performs the conventions DOTORI already defines, and nothing beyond them. It is
deliberately generic — if your work needs domain-specific steps (a project log format, a
document standard, a naming rule), write your own skill that calls for them. This one stays
out of that.

## 1. What was learned — memory

Ask: **will this be true again next time, in another project?** If not, it is session
noise. Do not record it.

If yes, write or update a memory in the runtime's own memory folder — the one DOTORI
mirrors — using the schema in [docs/memory.md](../../docs/memory.md):

```yaml
---
name: <kebab-case-slug>
description: <one line, used to judge relevance later>
metadata:
  node_type: memory
  type: project | feedback | reference | user
  status: capture | candidate | active | verified | durable | archived
  agent: <runtime id>
  evidence: []
  modified: <ISO 8601>
---
```

Two rules that decide whether the field means anything:

- **`verified` requires named evidence** — a path, a commit, test output, an incident.
  Put it in `evidence`. **Inference is not evidence.** If you cannot name what you checked,
  leave it at `active`. The sync counts memories that claim `verified` with nothing in
  `evidence`, so this is checked, not trusted.
- **Never drop `metadata` fields you do not recognise.** The schema is a convention no
  runtime enforces; the only thing protecting it is every writer leaving unknown keys alone.

Write the memory in the flat folder the runtime loads. Moving it into `shared/` or
`project/` is not filing it — it **removes it from what the agent sees**.

## 2. Where the work stands — projects

Only if the work will span sessions. One file per project in the vault's `projects/`:

- where it stands now
- what is next
- what is blocked and on what

This is **state**, not a record. The durable record belongs in your own notes; keep a
pointer here rather than a copy, because two copies drift and nothing tells you which is
current. Delete the file when the work ends.

## 3. If it continues on another machine — handoff

Only if the next step must happen somewhere else — a tool, an account, or a file that lives
on the other machine. `handoff/handoff-<machine>-<topic>-<date>.md`, containing:

- what changed
- what evidence was checked
- **what is not verified** — the section that earns its keep; without it the receiving side
  cannot tell what was tested from what merely looked finished
- known problems
- recommended starting point
- date and paths

Then note it in the entry document, which owns the list of open handoffs.

**Delete the handoff once the work is done and verified.** Deleting is the completion
signal. Handoffs marked done but left in place make the whole list untrustworthy, and the
sync reports how long each one has been sitting for exactly that reason.

## 4. Leave the workspace clean

Notes belong in the vault, not beside the source. If a rules file has grown past its
budget, move the overflow down a layer rather than letting the router carry it — every task
pays to read the router.

## What this skill will not do

| | Why |
|---|---|
| Promote anything into your human knowledge base | A person approves that. See [docs/candidates.md](../../docs/candidates.md) |
| Set `status: promoted` | Same reason — never set by an agent |
| Delete a memory | Retiring one is deliberate; the sync restores anything deleted locally |
| Run by itself | It fires when you ask. A session-end hook fires after every turn, which is the wrong granularity, and an unasked-for wrapup writes noise |
