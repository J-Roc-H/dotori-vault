# Running this on a genuinely clean Windows

The `Scope` section of the README used to say the install had never been run on a machine
that started with nothing. Three of the unknowns it named — execution policy, whether git is
present, PowerShell version — are machine state, and
[`tool/tests/FreshMachine.Tests.ps1`](../tool/tests/FreshMachine.Tests.ps1) now creates each
condition on purpose rather than waiting to be lucky.

Two things remain that a test cannot do: read the instructions as a stranger, and write a
hook into a **real** `settings.json` — CI has no agent runtime on it, so that path runs
against a fixture. That is what this page is for: about twenty minutes on a Windows that
has never seen this project.

## Two ways to get one

You do not need a spare computer. Either of these works, and they close different halves.

| | Windows Sandbox | A new local Windows account |
|---|---|---|
| Empty user profile — no `.claude\`, `.codex\`, `.ai-shared-sync\` | yes | yes |
| Default execution policy, not the one you relaxed years ago | yes | yes |
| **No git** | yes | **no** — git is usually on the system PATH for every account |
| Costs nothing to throw away | yes, close the window | you have to delete the account |
| **Writes a hook into a real `settings.json`** | only if you install a runtime, and it dies with the window | **yes, and it stays** |
| Needs firmware virtualization | **yes** | no |

The missing `git` is the smaller loss: `Mirror: git not found` is the one condition
`FreshMachine.Tests.ps1` already creates by taking git off the PATH, on every commit. The
real `settings.json` is the one nothing else reaches. **If you can only do one, do the
account.**

## Route A — Windows Sandbox

**It needs Windows Pro, Enterprise or Education, _and_ virtualization enabled in firmware**
(Intel VT-x, or AMD SVM). Both, not either.

If the **Windows Sandbox** checkbox in *Turn Windows features on or off* is **greyed out**,
that is almost always the second requirement, not the first — the tooltip says so, and it
happens on Pro. Turn it on in BIOS/UEFI, usually *Advanced → CPU Configuration →
`Intel Virtualization Technology`* or *`SVM Mode`*. On a company-managed machine that
setting is often locked, and no amount of clicking in Windows will help: use Route B.

Otherwise, enable it once — *Turn Windows features on or off* → **Windows Sandbox** →
reboot — and go to [The run](#the-run). Everything is discarded when you close the window,
so a bad attempt costs nothing.

On Windows Home, any throwaway VM does the same job, but check `git --version` fails and
`Get-ExecutionPolicy` is not `Bypass` before you start: a VM you have used before may have
neither condition left.

## Route B — a new local Windows account

**1. Create it.** *Settings → Accounts → Family & other users → Add someone else to this
PC* → *I don't have this person's sign-in information* → *Add a user without a Microsoft
account*. **It must be a local account.** Sign in with a Microsoft account and OneDrive and
your synced settings arrive with it, and the profile is no longer empty.

**2. Switch to it and check the conditions before running anything.** Start menu → your
user icon → the new account. Then, in PowerShell:

```powershell
$PSVersionTable.PSVersion    # 5.1 on stock Windows
Get-ExecutionPolicy          # must not be Bypass
'.claude','.codex','.ai-shared-sync' | ForEach-Object {
    "$_ : " + (Test-Path (Join-Path $env:USERPROFILE $_)) }   # all three False
git --version                # present is fine here - see the table
```

If any of the three paths is `True`, you are not in the account you think you are.

**3. Get the repository in.** You cannot read the other account's profile. Download the zip
from GitHub, or, from your normal account, copy the folder to `C:\Users\Public\dotori-check\`
first and use it from there.

## The run

Everything below is the same on either route. `$env:USERPROFILE` resolves to whichever
account you are in.

**1. Look before anything runs.** From the repository folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\sync-ai-shared.ps1 `
  -Mode Report -VaultRoot "$env:USERPROFILE\dotori-vault"
```

Expect a block beginning `DOTORI - what Initialize would do on this machine`. Read the
**Settings files it would EDIT** section. Nothing has been written yet.

**2. Try it without the flag.** Same command, `-ExecutionPolicy Bypass` removed. It should
be refused. If it is *not* refused, this account has a policy you did not expect — say so in
the report, because the README hands people that flag and this is the check that it earns
its place.

**3. Install, following README step 2 literally.** Copy `tool\sync-ai-shared.ps1` to the
vault root, `tool\scripts\sync-ai-shared.ps1` into its `scripts\`, and
`vault_ai\skills\wrapup\` into its `skills\`. Then:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dotori-vault\sync-ai-shared.ps1" `
  -Mode Initialize -VaultRoot "$env:USERPROFILE\dotori-vault"
```

Expect three things:

- a **no settings file** warning for each runtime, because none is installed yet:

  ```
  WARNING: No settings file at C:\Users\<you>\.claude\settings.json - no hook installed
  there. Install the runtime first, then run this again, or the sync will only run when you
  start it by hand.
  ```

  **That is the expected result, not a failure** — the script refuses to fabricate another
  tool's config file, and this is the run where you watch it refuse.
- a warning that the vault `does not look like a folder any` sync service carries between
  machines — correct, because it is a plain local folder
- a closing block starting `Installed. What you have now`, whose `Between machines` line
  should say `Nothing yet`

**4. Read the log.** `sync\sync-log-<machine>.md` in the vault. Everything should have run.
The `Mirror:` line differs by route: `git not found` in the sandbox — that is the condition
it exists for — and a normal mirror result in a new account, where git is still on the PATH.

## The part only Route B reaches

This is the half CI cannot do. Skip it and the run is still worth reporting; do it and you
have checked something nobody has.

**1. Install one agent runtime in that account** — whichever you actually use — and start it
once so it writes its own config.

**2. Confirm `%USERPROFILE%\.claude\settings.json` exists.** If starting the runtime did not
create it, stop and report that: the script's warning is right, and the README's step order
needs to say so.

**3. Run `-Mode Initialize` again.** Now:

- the **no settings file** warning is gone
- `settings.json` has a command ending `sync-ai-shared.ps1" -Mode Sync` under **both**
  `hooks.SessionStart` and `hooks.Stop`
- `%USERPROFILE%\.ai-shared-sync\backups\<timestamp>\` holds a copy of the file as it was

**4. Compare the backup with the new file.** This is the most valuable thing on this page.
Writing the hook round-trips your live settings through `ConvertFrom-Json` and
`ConvertTo-Json -Depth 20`, and PowerShell 5.1's serializer is not lossless: it escapes
non-ASCII to `\uXXXX`, reformats, and truncates below the depth limit. Against a fixture
that is invisible.

```powershell
$b = "$env:USERPROFILE\.ai-shared-sync\backups\<timestamp>\settings.json"
$n = "$env:USERPROFILE\.claude\settings.json"
Compare-Object (Get-Content -Raw $b | ConvertFrom-Json).PSObject.Properties.Name `
               (Get-Content -Raw $n | ConvertFrom-Json).PSObject.Properties.Name
Select-String -Path $n -Pattern '\\u[0-9a-fA-F]{4}'
```

Reformatting is known and fine. A top-level key that disappeared, or a `\uXXXX` where the
backup had a readable character, is a bug — report it with both files.

**5. Start a session in the runtime and watch the hook fire.** The modified time of
`sync\sync-log-<machine>.md` should move on its own. That is the first end-to-end proof of
the thing the README promises: install it once, and it runs by itself from then on.

## Cleaning up

*Settings → Accounts → Family & other users* → select the account → **Remove**, which
deletes the profile and everything this run put in it — vault, mirror, backups, hooks. If
you staged the repository in `C:\Users\Public\dotori-check\`, delete that too. Your own
account was never touched.

## What to report

Use the [fresh install report](https://github.com/J-Roc-H/dotori-vault/issues/new?template=fresh-install-report.yml)
template. Paste the log whole, and say which route you took and whether you did the
runtime step.

The part worth more than the log: **anything you had to re-read, guess at, or look up.**
The counts in the log are already checked by CI on every commit. Whether step 3 was clear
enough to follow without knowing how the thing works is the question no test can answer,
and it is the reason this page exists.

A report saying nothing broke is worth exactly as much as one saying it did.
