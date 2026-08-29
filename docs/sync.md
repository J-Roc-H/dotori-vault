# Sync

Memory moves in both directions. Everything else is published outward from the shared
vault. This document covers the memory case, because it is the only one where two sides
can both be right.

## The three-way comparison

Each run compares three values per file:

```
baseline   the hash recorded in this machine's manifest at the end of the last run
local      this machine's copy right now
shared     the vault's copy right now
```

| Local vs baseline | Shared vs baseline | Result |
|---|---|---|
| same | same | nothing to do |
| changed | same | **push** |
| same | changed | **pull** |
| changed | changed | see below |

A file present on only one side is **copied, not deleted**. Deletions are never
propagated: a memory missing locally is restored from the archive. Retiring a memory
should be a deliberate act, not a side effect of sync.

## When both sides changed

Not every "both changed" is a disagreement. Compare the text with a byte-order mark and
carriage returns discounted:

| Text identical? | Result | Who decides |
|---|---|---|
| yes | **normalized** — converge the bytes, keep going | nobody; there is nothing to decide |
| no | **conflict** — touch neither side, log the path | you |

### Why this distinction matters

A raw byte hash cannot tell a real edit from an encoding rewrite. Some editor or script
saves a file with a byte-order mark, or leaves two lines with CRLF where the rest are LF,
and the file now hashes differently on both sides while saying exactly the same thing.

That alone is survivable. What makes it serious is that **a conflict keeps its previous
baseline on purpose**, so the next run makes the same comparison and reaches the same
conclusion. Nothing self-heals. In one recorded case fifteen conflicts brought memory sync
to a complete stop — `pushed 0 / pulled 0` — and eight of the fifteen turned out to be a
single byte-order mark or two stray carriage returns.

### The limits of the normalization

It discounts a byte-order mark and carriage returns. That is all.

Do not widen it to ignore whitespace in general. Trailing spaces inside a memory are
content, and collapsing them would hide a real edit — which is exactly the failure the
conflict mechanism exists to prevent.

It also does not replace the raw hash. The manifest still records byte hashes, because
"did this file change at all" is a different question from "is the text different".

## Resolving a real conflict

The tool will not choose for you. Open both copies and decide, then make the two sides
identical so the next run sees agreement.

Two habits worth keeping:

**Check the timestamps before assuming the newer side wins.** Usually it does. Sometimes
the older side is the one that got a correction the newer one never received.

**Watch for a machine-local fact written as a universal one.** A memory that says a helper
script "does not exist" may mean it does not exist *on the machine that wrote the memory*.
Anything living outside the shared vault is per-machine by definition, so scope the claim
to the machine rather than deleting it.

## Lifecycle

Memories carry a lifecycle field. Every run counts them and lists any that are missing it:

```
Lifecycle: active=80 verified=6 / no-status=0
```

`no-status` above zero means something rewrote a memory and dropped the field. The check
exists because the schema is a convention, not something the agent runtime enforces — and
without a drift counter, an unenforced convention quietly becomes dead metadata nobody
updates.

Promotion to `verified` requires recorded evidence: a file path, a commit, test output, an
incident. **Inference is not evidence.** If you cannot name what you checked, leave it at
`active`.
