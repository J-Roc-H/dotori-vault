# Changelog

Dates are omitted deliberately: this is extracted from a working setup, and the internal
history contains private material. What is preserved is the order and the reason.

## Unreleased

First public extraction. Nothing has been released yet.

### The architecture at this point

- Two vaults: one for human knowledge, one for agent operating state
- Machine identity derived from the account running the sync, so machine count is not a
  fixed value anywhere in the code
- Agents, skills and rules published outward to each installed runtime; missing runtimes
  skipped with a warning rather than an error
- Memory synced in both directions with a three-way comparison, stopping on genuine
  conflicts and resolving encoding-only ones
- Per-machine manifest, log and memory index
- Git history kept outside the cloud-synced vault
- Publication through an allowlist with a fail-closed scrub gate

### Fixed on the way to extraction

- **Memory sync could freeze permanently.** A byte-order mark or a few stray carriage
  returns made both sides look edited, which reported a conflict, and a conflict keeps its
  previous baseline by design — so nothing self-healed. Content is now compared with those
  discounted before a conflict is declared.
- **The publish gate had a hardcoded machine name.** A machine not in that hand-written
  list would be neither scrubbed nor caught by the assertion meant to prove the scrub
  fired. Machine identities are now discovered, each generating a scrub rule and its
  matching assertion, with a catch-all for anything still shaped like an unaccounted-for
  machine name.
- **`Skills synced: N` was a file count read as a skill count.** A specification was once
  written against the misreading. The label now names its unit — and once it did, the gap
  between the two numbers turned out to be two stale editor copies that had been quietly
  published into every runtime, each declaring the same skill name as the file beside it.
  Labelling the unit is what made them visible.
- **Per-runtime coverage was invisible.** One aggregate number hid a runtime receiving
  nothing. The log now reports each runtime separately.
- **Published docs were scrubbed private documents.** They came out in the wrong language
  and carried links to documents that do not exist publicly. All prose here is now written
  for publication.

### Found by the first clean-install rehearsal

The install had never been run as written — only by hand, onto machines that already had a
working setup. Rehearsing it into an empty directory tree found three faults, each of which
is invisible on a machine that is already configured:

- **Initialize copied the script onto itself and died.** Following the documented steps
  puts the running script at the install target, and `Copy-Item` refuses that, so the
  install failed at its last step with exit code 1. The Sync path had guarded against it
  for as long as it existed; Initialize never had.
- **A hardcoded repository URL** made every install anywhere adopt one particular private
  repository as its git origin and fetch from it. Now a parameter, empty by default, with
  a publish-gate check so no owner-bearing URL can ship again.
- **A missing hook was installed in silence.** With no settings file yet present, the hook
  installer returned without a word: exit code 0, success reported, nothing installed —
  against documentation promising it would run every session from then on.

The rehearsal was only possible after making the Antigravity rules path a parameter. It
was the one write no parameter could redirect, so any rehearsal would have overwritten the
real file.

See [docs/evolution.md](docs/evolution.md) for the structures that preceded this one and
what each of them failed at.
