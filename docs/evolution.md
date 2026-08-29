# How this arrived at its current shape

Every structure here replaced one that failed in a specific way. The failures are the
useful part — the end state alone does not tell you which pieces are load-bearing.

Dates are omitted. What matters is the order and the cause.

## 1. One vault, everything in it

A personal knowledge vault, then an AI agent pointed at it.

**Failed because** agent working state and human knowledge have opposite lifecycles.
Session scratch, unverified findings, and half-finished work flowed into the same space as
settled decisions, and nothing marked which was which.

**Became** two vaults. One holds what a person knows and decides. The other holds what
agents need in order to keep working: rules, skills, agent definitions, memory, handoff
notes, sync state.

The split is not the goal. Being able to say *which one is authoritative* is the goal.

## 2. A rules file in every folder

A rules file at the vault root, another in each major folder, each describing how to work
in that area.

**Failed because** the runtime only loads the one in the working directory. The rest were
documents that described behavior nobody ever got. They looked maintained; they were dead.

**Became** a single router outside the vault, at a path the runtime always reads, which
points at per-domain guides. See [routing.md](routing.md).

## 3. One accumulated core

All hard-won rules in one growing file.

**Failed because** every task paid to read all of it. Rules specific to one kind of work
were loaded for every other kind.

**Became** a global core plus per-domain cores. The global one holds what applies
everywhere; a domain core adds to it and never replaces it.

## 4. One-way memory publication

The shared archive overwrote each machine's local memory on every run.

**Failed because** whichever machine synced last silently discarded the others' memories,
and a new machine had no way to contribute anything.

**Became** a three-way comparison, in both directions, that stops on conflict rather than
merging. See [sync.md](sync.md).

## 5. One shared manifest, log, and memory index

Single copies of each, inside the cloud-synced vault.

**Failed because** they are rewritten on every session start and stop. The cloud service
turned the losing writes into conflict copies — dozens of them within a day — and the
shared manifest meant the last machine to sync overwrote everyone's baseline.

**Became** per-machine files keyed by the account running the sync. This is also what
removed any fixed machine count from the code. See [multi-machine.md](multi-machine.md).

## 6. Raw byte hashes as the only comparison

A file was "changed" if its bytes differed from the recorded hash.

**Failed because** a byte-order mark or a couple of stray carriage returns is a byte
change and not a content change. Both sides would look edited, the run would report a
conflict, and a conflict deliberately keeps its old baseline — so nothing self-healed.
Memory sync stopped entirely and stayed stopped.

**Became** a second, narrower comparison used only when both sides look changed: if the
text matches once a byte-order mark and carriage returns are discounted, converge the
bytes and continue. The raw hash still decides whether a file changed at all.

## 7. A hardcoded name in the public build

The build that produces the publishable subset scrubbed identity-bearing strings, with
one machine name written into the list by hand.

**Failed because** the list did not grow when the machines did. An unlisted machine name
would be neither scrubbed nor caught by the assertion that was supposed to guarantee the
scrub had fired — a leak that passes its own safety check.

**Became** machine identities discovered from the per-machine filenames they leave behind,
generating a scrub rule and its matching assertion together, plus a catch-all that fails
the build on anything still shaped like an unaccounted-for machine name.

## What holds across all of them

**A convention nobody counts is already broken.** Every rule that survived has a counter
attached — conflicts, missing lifecycle fields, per-runtime coverage. The ones that had no
counter drifted without anyone noticing.

**Fail closed, and never weaken the check to get past it.** When the publish gate blocked
a document, the fix was to drop the document and write a new one for publication — not to
loosen the pattern.

**A number in a log needs its unit.** A count labelled ambiguously gets read as the wrong
quantity, and then a specification gets written against the misreading.
