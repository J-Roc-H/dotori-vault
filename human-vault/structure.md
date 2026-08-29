# Folder structure

A skeleton, not a prescription. What matters is the three properties below; the specific
domains should be yours.

```
vault/
|
+-- 00_Inbox/          unsorted capture. Everything lands here first
+-- 01_<domain>/       one folder per domain of work
+-- 02_<domain>/
+-- 03_<domain>/
+-- ...
+-- 0N_Reference/      material you did not write
+-- 0N_Ideas/          not yet a project
|
+-- Templates/         note templates
+-- _archive/          superseded structures, kept as evidence
```

## The three properties

**Numbered prefixes.** They fix the display order, which means the order communicates
something. Domains you touch daily sort above ones you touch monthly.

**One domain per folder, with its own working guide.** Each domain folder owns a guide
naming what to read before starting work in it. That file is what the router points at —
see [../docs/routing.md](../docs/routing.md).

**An inbox with an exit rule.** Capture is worthless without a discipline for emptying it.

## The inbox rule

Capture is cheap and sorting is expensive, so the inbox fills up and stops being read.
Three rules keep it moving:

1. **Do not edit what you captured.** Typos included. Interpretation happens in the
   destination note, not here — otherwise you lose the original wording that made you
   capture it.
2. **Stamp it when processed**, with the date and where it went.
3. **Move it immediately once stamped.** The inbox holds unprocessed items only.

Anything unstamped past a threshold — thirty days works — is a backlog signal, not a
normal state.

**Nothing here reports it for you.** DOTORI's sync does not read this vault at all: it is
your knowledge, and a tool that walked through it to count things would be reaching into
the wrong half of the split this whole structure exists to keep. If you want the signal,
it is a one-line search of your own — the point of writing the rule down is that you know
what to look for.

## Renumbering

Numbered folders resist insertion, and eventually you will restructure. Two things make
that survivable:

**Leave gaps.** Numbering by ones means the first insertion renumbers everything after it.

**A path substitution is not done when the old paths are gone.** Verify on three axes:
no stale references remain, every new target actually exists, and paths built by
concatenation in scripts were caught too — those never appear in a plain text search.

## Archiving

`_archive/` holds structures that were replaced, not things that stopped being useful.
Keeping the old shape is what lets you reconstruct why the current one exists — see
[../docs/evolution.md](../docs/evolution.md). A replaced structure with no record of what
it failed at is a change nobody can evaluate later.
