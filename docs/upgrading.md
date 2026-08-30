# Moving an existing installation to this version

If you already run DOTORI, this page is the whole upgrade. If you are installing for the
first time, you want [the README](../README.md) instead — none of this applies to you.

The README describes a first install. Until now nothing described a second one, which is a
gap of the same kind as the others this project keeps finding: the documents covered the
beginning and not the middle.

Three things changed that touch an existing vault. None of them deletes anything, and the
third one is optional.

---

## 1. The machine key is now the computer name

It used to be the account name. That satisfied half of what
[spec.md](spec.md) requires — stable across runs — and not the other half, distinct between
machines. Two machines signed in as the same account shared one manifest, one log and one
memory index, which is the failure per-machine naming exists to prevent, and it reported
nothing while it happened.

**What the first run does.** It finds your files under the old key and copies them to the
new one:

```
sync\sync-manifest-<account>.json   ->  sync\sync-manifest-<COMPUTER>.json
sync\sync-log-<account>.md          ->  sync\sync-log-<COMPUTER>.md
memory\claude-handoff\MEMORY-<account>.md -> MEMORY-<COMPUTER>.md
```

**Copies, not moves.** Deletions are never propagated here, and another machine may still
be running the old version and reading the old names. The stale copies are listed once in
the log under *Superseded per-machine files*. Delete them by hand **after every machine
sharing the vault has run this version at least once** — not before.

Your handoff read-state comes across with the manifest, so upgrading does not replay old
handoffs as new.

**If your two machines share a computer name**, pass `-MachineKey` on one of them with
something unique. You will not have to guess: the run stops with an error rather than
adopting the other machine's baseline.

## 2. Session hooks are written by `Initialize` only

They used to be rewritten on every `Sync` — which the `Stop` hook fires after *every turn*,
not once per session. Your `settings.json` was being round-tripped through a JSON serialiser
continuously.

Your existing hooks are unaffected and keep working; nothing needs doing. If you ever remove
one, run `-Mode Initialize` again to put it back.

---

## 3. The vault is now documented as one of two folders (optional)

The layout this project documents is a workspace holding two vaults:

```
<workspace>/
+-- vault_ai/       <- the vault. -VaultRoot points here
+-- vault_human/
```

**Nothing in the code requires this.** The script has never known the human vault exists
and still does not. `-VaultRoot` points at the AI vault, and it does not care what the
folder is called or what sits beside it. This is a naming convention so that two people
describing their setup mean the same thing, and adopting it is a decision you can decline
at no cost.

### If you do move, read this first

**Renaming your vault folder breaks every session hook that points into it.** That is not
a recoverable-by-syncing situation: the hook is what runs the sync, so a machine with a
broken hook cannot receive the fix. It has to be repaired on that machine, by hand.

So do it one machine at a time, and finish each before starting the next:

1. **Write down what you have.** On the machine, from your clone:

   ```powershell
   .\tool\sync-ai-shared.ps1 -Mode Report -VaultRoot "<current vault>" -MirrorRoot "<mirror root>"
   ```

   It writes nothing. Note the settings files it lists and the hook line it prints — that
   is what you are about to invalidate.

2. **Let the sync service settle.** Move or rename the folder, then wait for your sync
   client to finish. Renaming a synced folder can look to the service like deleting one
   tree and creating another; starting the next step mid-upload gets you a partial vault.

3. **Re-run `Initialize` on that machine**, pointed at the new path:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<new vault>\sync-ai-shared.ps1" `
     -Mode Initialize -VaultRoot "<new vault>"
   ```

   This rewrites the hook. It is the only step that repairs it.

4. **Delete the old hook entry** from each settings file the report named in step 1.
   `Initialize` adds the new one; it does not remove the stale one, so leaving it there
   means every session from now on starts by failing to run a script that is not there.

5. **Confirm before moving on.** Start a session and check that `sync\sync-log-<machine>.md`
   under the new path has a fresh timestamp. Only then do the next machine.

Until every machine is done you are running a split setup — some machines on the old path,
some on the new. That is survivable (they are different folders, so neither corrupts the
other) but they will not see each other's memory, so keep the window short.

---

## The upgrade, in order

Do one machine completely, confirm it, then do the next.

**1. Look first.** From your clone, pointed at your real vault:

```powershell
.\tool\sync-ai-shared.ps1 -Mode Report -VaultRoot "<your vault>" -MirrorRoot "<your mirror root>"
```

This writes nothing. Check that it names the machine key you expect and the settings files
you expect.

**2. Keep a way back.** The vault's git history lives outside the vault and already has
your current state; `.\tool\brain-git.ps1 log --oneline` will show it. If you want belt and
braces, copy `sync\` and `memory\` somewhere outside the vault first.

**3. Replace the two scripts in the vault** with the ones from this repository — the shim at
the vault root, the implementation in `scripts\`. Keep the shim's path exactly as it is:
every machine has that path baked into its session hook, and a machine whose hook is broken
can never run the sync that would deliver the fix.

**4. Copy `vault_ai\skills\wrapup\` into your vault's `skills\`** if you want the shipped finishing
routine. Skip it if you already have your own — it is generic on purpose and yours will be
better for your work.

**5. Run a sync.**

```powershell
.\tool\sync-ai-shared.ps1 -Mode Sync -VaultRoot "<your vault>" -MirrorRoot "<your mirror root>"
```

**6. Read the log.** `sync\sync-log-<COMPUTER>.md`. Expect:

| Line | What it should say |
|---|---|
| `Machine:` | your computer name, not your account name |
| `Memory:` | `conflicts 0` — an upgrade should not produce any |
| `Superseded per-machine files` | the old-key copies, listed once. Leave them for now |
| `unevidenced=N` | probably not zero, and that is fine — see below |
| `Handoffs older than 14 days` | probably not zero either |

**7. Then the next machine.** Same steps. Once every machine has run once, delete the
superseded copies the logs listed.

---

## The new counts will not be zero, and that is the point

Three counters exist now that did not before, and on an established vault they will find
things immediately:

- **`unevidenced`** — memories claiming `verified` or higher with an empty `evidence` list.
  The rule was always there; nothing checked it. Either name what you checked, or move them
  back to `active`. `active` is the honest resting place for something you have not verified,
  and there is no penalty for sitting in it.
- **Handoffs older than 14 days** — deleting one is the completion signal, so an old one is
  either forgotten or finished-and-left. Both make the next real handoff less believed.
- **Candidates waiting** — the promotion queue has a human gate, and nothing was reporting
  that the gate had not been used.

None of these are errors and none block a run. A first upgrade that surfaces a backlog is
the counters working, not the upgrade failing.

## Rolling back

Put the previous scripts back and run a sync. Nothing was deleted: the old-key files are
still there, the new-key files become the stale ones, and memory is untouched either way.
The git mirror has every state in between if you want a specific one —
`.\tool\brain-git.ps1 log --oneline` then `checkout`.
