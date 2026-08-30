# The human vault

The other half of DOTORI. This is where a person's knowledge lives; the AI vault holds
what agents need in order to work.

**Only the skeleton is published here** — the folder shape, the routing convention, and
the note templates. The contents of a personal vault are personal.

## What belongs on each side

| Human vault | AI vault |
|---|---|
| What we know and have decided | What an agent needs in order to keep working |
| Documents, projects, references, creative work | Rules, skills, agent definitions |
| Long-lived, human-authored, stable | Memory, handoff notes, sync state |
| A person has final say | Agents write here freely |

The test is lifecycle, not subject matter. A finding an agent produced belongs in the AI
vault until a person has verified it and decided it is worth keeping — then it is promoted.
See [../docs/candidates.md](../docs/candidates.md).

## Rules

**Memory is not knowledge.** An agent's memory records what it learned about working with
you — including things not yet verified. The human vault records what is settled. Keeping
them apart is what lets you trust one of them.

**Promotion is one-way and human-approved.** Agents never write into the human vault
directly, and never set a memory's `promotedTo` on their own. That field records where a
finding landed here, and only a person knows that.

**No credentials, session logs, caches, or runtime state in either vault.** Those live
outside both, next to the git directory.

## Files here

| File | What it is |
|---|---|
| [structure.md](structure.md) | The folder skeleton and why it is numbered |
| [templates/](templates/) | Note templates, empty |
