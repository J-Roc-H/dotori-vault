# Candidates

Things an agent thinks are worth promoting into human knowledge.

## Not the same as `memory/candidate/`

These two are easy to confuse, so the distinction is worth stating plainly:

| Folder | The question it asks | If it passes |
|---|---|---|
| `memory/candidate/` | Is this worth **remembering**? | moves to `memory/shared/` |
| `candidates/` | Is this worth **adding to what the person knows**? | promoted to the human vault |

The first is about an agent's own working memory. The second is about someone's knowledge
base. Something can easily be worth the first and not the second.

## Promotion criteria

All four, not any:

- **Verified** — there is evidence and a way to reproduce it
- **Reproducible** — it will come out the same way next time
- **Durable** — useful beyond the task that produced it
- **Human knowledge** — it is something the person should know, not an operating detail
  about how the agents are wired

That last one filters the most. Plenty of true, verified, durable facts are still just
agent plumbing.

## The rule

**An agent finding something does not make it human knowledge.**

Promotion is never automatic and is approved by a person. Once promoted, remove it from
here and set `promotedTo` on the source memory to the path it landed at in the human vault.

**Leave the memory's `status` alone.** Promotion is a separate axis from the lifecycle —
a durable memory that reaches the human vault is still durable. `promotedTo` is where the
promotion is recorded; `status` keeps answering its own question. See
[memory.md](memory.md).

The reason for the approval gate is that a knowledge base is only useful if its owner
trusts everything in it. One unreviewed entry does not just add noise — it makes every
neighbouring entry require a second look.
