# Running this on a genuinely clean Windows

The `Scope` section of the README used to say the install had never been run on a machine
that started with nothing. Three of the unknowns it named — execution policy, whether git is
present, PowerShell version — are machine state, and
[`tool/tests/FreshMachine.Tests.ps1`](../tool/tests/FreshMachine.Tests.ps1) now creates each
condition on purpose rather than waiting to be lucky.

What a test cannot do is read the instructions as a stranger. That is what this page is for:
about twenty minutes, on a Windows that has never seen this project.

## Why Windows Sandbox

It gives you, free and without touching your own setup:

| | |
|---|---|
| A clean Windows, every launch | Nothing carried over from the last attempt |
| **No git** | The exact condition `Mirror: git not found` exists for |
| Default execution policy | Not the one you relaxed on your own machine years ago |
| An empty user profile | No `.claude\`, no `.codex\`, no `.ai-shared-sync\` |

Everything is discarded when you close the window, so a bad run costs nothing.

**Sandbox needs Windows Pro, Enterprise or Education.** On Home, use any throwaway VM — the
steps are the same, but remember to check `git --version` fails and
`Get-ExecutionPolicy` is not `Bypass` before you start, since a VM you have used before
may have both.

Enable it once: *Turn Windows features on or off* → **Windows Sandbox** → reboot.

## What Sandbox will not give you

**No agent runtime is installed.** So `Initialize` finds no `settings.json` and installs no
hooks. **That is the expected result, not a failure** — the script refuses to fabricate
another tool's config file, and this is the run where you watch it refuse. You should see:

```
WARNING: No settings file at C:\Users\WDAGUtilityAccount\.claude\settings.json - no hook
installed there. Install the runtime first, then run this again, or the sync will only run
when you start it by hand.
```

If you want the hook-writing path exercised too, install one runtime inside the sandbox
first and run it again. That is the one piece CI cannot reach either, because the runners
have no agent runtime on them.

## The run

**1. Get the repository in.** Drag the folder from your host into the sandbox window, or
download the zip from GitHub inside it. Do not clone — there is no git, which is the point.

**2. Look before anything runs.** From the repository folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\sync-ai-shared.ps1 `
  -Mode Report -VaultRoot "$env:USERPROFILE\dotori-vault"
```

Expect a block beginning `DOTORI - what Initialize would do on this machine`. Read the
**Settings files it would EDIT** section. Nothing has been written yet.

**3. Try it without the flag.** Same command, `-ExecutionPolicy Bypass` removed. It should
be refused. If it is *not* refused, your sandbox has a policy you did not expect — say so in
the report, because the README hands people that flag and this is the check that it earns
its place.

**4. Install, following README step 2 literally.** Copy `tool\sync-ai-shared.ps1` to the
vault root, `tool\scripts\sync-ai-shared.ps1` into its `scripts\`, and
`vault_ai\skills\wrapup\` into its `skills\`. Then:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dotori-vault\sync-ai-shared.ps1" `
  -Mode Initialize -VaultRoot "$env:USERPROFILE\dotori-vault"
```

Expect three things:

- the **no settings file** warning above, for each runtime
- a warning that the vault does not look like a folder any sync service carries — correct,
  because it is a plain local folder in a sandbox
- a closing block starting `Installed. What you have now`, whose `Between machines` line
  should say `Nothing yet`

**5. Read the log.** `sync\sync-log-<machine>.md` in the vault. `Mirror:` should read
`git not found`, and everything else should still have run.

## What to report

Use the [fresh install report](https://github.com/J-Roc-H/dotori-vault/issues/new?template=fresh-install-report.yml)
template. Paste the log whole.

The part worth more than the log: **anything you had to re-read, guess at, or look up.**
The counts in the log are already checked by CI on every commit. Whether step 4 was clear
enough to follow without knowing how the thing works is the question no test can answer,
and it is the reason this page exists.

A report saying nothing broke is worth exactly as much as one saying it did.
