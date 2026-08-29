# Contributing

This is a personal setup that other people can use, maintained by one person with a day
job. That shapes everything below. The aim is to be honest about it rather than to sound
welcoming and then go quiet.

## What this project takes

**Core owns mechanism. Core does not ship domain content.**

That one rule decides almost every case. The test is: *is this true across domains, or is
it true for your work?*

| Belongs here | Does not |
|---|---|
| A runtime adapter (a new agent tool's paths and formats) | A skill for your job, tool, or team |
| A conflict-copy shape your sync service produces | Your router or rules file |
| A clarification or correction to `docs/spec.md` | Your agent definitions |
| A second implementation on another platform | A workflow with your employer's policy in it |
| A test case for an invariant | |
| A bug fix | |

Skills, workflows and recipes are worth sharing — just not from inside this repository.
Put them in your own repo. Once a few exist, they will get an index here; there is no
point building one for a list that is empty.

## The two reports worth the most

These cover ground this project cannot reach on its own, and they are the ones that get
answered first.

**What your sync service does.** The conflict-copy shapes in
[docs/multi-machine.md](docs/multi-machine.md) came from documentation and from one service
in daily use. If yours leaves something the log does not recognize, say what it looks like.
Adding a shape is a one-line change.

**What a fresh machine does.** The install has been rehearsed into an empty directory tree
and is covered by tests on a clean Windows runner, but the number of people who have run it
on a real Windows machine that started with nothing is still very small. A report saying
what broke — or that nothing did — is the single most useful thing anyone can send.

## Bugs

Include `sync\sync-log-<machine>.md`. Most reports are unanswerable without it, and the log
is designed to make the diagnosis obvious.

## Pull requests

Run the tests first:

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser
Invoke-Pester -Path tests
```

CI runs them on `windows-latest` along with PSScriptAnalyzer and a check that no `.ps1`
file contains a non-ASCII byte. PowerShell 5.1 decodes a BOM-less script as ANSI, so a
stray non-ASCII literal becomes mojibake at runtime — hence the check rather than a note
asking people to remember.

Say in the PR which of the invariants in [docs/spec.md](docs/spec.md) section 9 your change
touches, if any. Changes to the spec itself are a conversation before they are a patch.

## What to expect

**Bugs get fixed. Most other things get read and not much else.** Issues are read; replies
can take a while, and a PR that adds surface rather than removing a fault will probably sit.
This is not a judgement on the contribution — it is one person's capacity, stated up front
so nobody wastes an evening on something that will not land.

If that is not the deal you want, the more durable answer is below.

## If this project stops

The vault is plain Markdown in folders and the git history is ordinary git. Nothing here
holds your data hostage: delete the script and everything you have is still readable by
anything that opens a text file.

[docs/spec.md](docs/spec.md) is the on-disk contract, defined precisely enough to write
another implementation against — that is the point of writing it down. If this repository
goes quiet, the format outlives it, and a fork or a second implementation loses nothing.
