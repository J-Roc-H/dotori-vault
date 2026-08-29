# Search index

Reserved. Full-text search over the vault's Markdown, so an agent can find a memory it was
not explicitly handed.

## Where the database goes

**Not in the vault.** Resolution order:

| Priority | Source |
|---|---|
| 1 | `--db` argument |
| 2 | environment variable |
| 3 | a local application-data path (default) |

Each machine builds its own. It is never shared.

## Why not in the vault

It was, once. The rebuild trigger fired at the end of every session, so every machine
rewrote the same SQLite file inside a cloud-synced folder on every turn. The result:

- 158 conflict copies plus orphaned temp files, together over 100 MB
- roughly two thirds of the mirror's commits were those copies
- and the live database itself was a zero-byte cloud placeholder — dead

Nobody noticed it was dead because nothing was querying it yet.

The general failure — several machines writing one file in a cloud folder — is the same
one that per-machine manifests and logs solve by splitting the filename. **But the fix
here is different.** A derived artifact should not be shared at all. Splitting its name
would give every machine its own copy of something that should never have been in the
synced folder to begin with.

That is the rule worth taking away: for state, give each machine its own name; for derived
data, take it out of the shared folder entirely.

## The invariant

**An index is not a source of truth.** It must be rebuildable from Markdown and git alone.

If deleting the index would lose something unrecoverable, the design is wrong — the index
has quietly become the only home for something, and it is the one component with no
backup story.
