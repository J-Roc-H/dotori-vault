# Ten minutes, on a path you can delete

The point of this page is to let you watch DOTORI work **without touching your real setup**.
Everything below happens inside one scratch folder. Delete it at the end and your machine is
exactly as it was.

You need Windows, PowerShell 5.1 (it ships with the OS), and one of the supported agent
runtimes installed if you want to see publication actually land somewhere.

---

## 1. Look before anything runs (1 minute)

```powershell
cd <where you cloned this repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\sync-ai-shared.ps1 `
  -Mode Report -VaultRoot "$env:TEMP\dotori-demo\vault" `
  -MirrorRoot "$env:TEMP\dotori-demo\local"
```

This writes nothing. It tells you which runtimes it found, where things would go, and —
the part worth reading — which settings files it would edit and the exact hook line it
would add.

Note what it says about your **real** `settings.json`. You have not agreed to anything yet.

---

## 2. Build a scratch machine (2 minutes)

Rather than pointing at your real runtime folders, make fake ones. Every path is a
parameter, so nothing here is a special test mode — it is the ordinary install, aimed
somewhere disposable.

```powershell
$demo = "$env:TEMP\dotori-demo"
$a    = "$demo\machine-a"
mkdir "$a\claude\agents", "$a\claude\skills", "$a\claude\projects\demo\memory", `
      "$a\codex", "$a\antigravity", "$a\local", "$demo\vault" -Force | Out-Null
```

Give it one agent and one memory, so there is something to move:

```powershell
@'
---
name: demo-reviewer
description: Checks a draft against the project standards before it ships.
tools: Read, Glob
---

You verify. You do not implement.
'@ | Set-Content "$a\claude\agents\demo-reviewer.md" -Encoding UTF8

@'
---
name: demo-lesson
description: Check the output folder before theorising about an output bug
metadata:
  node_type: memory
  type: feedback
  status: active
  agent: demo
  modified: 2026-01-20T14:30:00.000Z
---

Open the real output folder before forming a hypothesis.
'@ | Set-Content "$a\claude\projects\demo\memory\demo-lesson.md" -Encoding UTF8
```

---

## 3. Install into the scratch tree (1 minute)

```powershell
$common = @{
  VaultRoot = "$demo\vault"; ClaudeHome = "$a\claude"; ClaudeRoot = "$a\claude-root"
  CodexHome = "$a\codex";    AntigravityHome = "$a\antigravity"
  MirrorRoot = "$a\local";   MachineKey = 'DEMO-A'
}
.\scripts\sync-ai-shared.ps1 -Mode Initialize @common
```

No hook is installed, because there is no `settings.json` in the scratch runtime folder —
and the script refuses to fabricate one. That is the designed behaviour, and it warns
rather than pretending it succeeded.

**Look at what happened:**

```powershell
Get-Content "$demo\vault\sync\sync-log-DEMO-A.md"
Get-Content "$a\codex\agents\demo-reviewer.toml"
```

The agent you wrote as Markdown has been converted to the format the other runtime expects,
description and tool restriction intact. That conversion is the thing DOTORI does that a
file-sync tool cannot.

---

## 4. Add a second machine (3 minutes)

This is the case the whole design exists for. Same vault, different everything else.

```powershell
$b = "$demo\machine-b"
mkdir "$b\claude\agents", "$b\claude\skills", "$b\claude\projects\demo\memory", `
      "$b\codex", "$b\antigravity", "$b\local" -Force | Out-Null

$commonB = @{
  VaultRoot = "$demo\vault"; ClaudeHome = "$b\claude"; ClaudeRoot = "$b\claude-root"
  CodexHome = "$b\codex";    AntigravityHome = "$b\antigravity"
  MirrorRoot = "$b\local";   MachineKey = 'DEMO-B'
}
.\scripts\sync-ai-shared.ps1 -Mode Initialize @commonB

Get-ChildItem "$b\claude\projects\demo\memory"
```

Machine B now has the memory machine A wrote, and its own agent copy — without either
machine reading the other's sync state.

---

## 5. Watch it refuse to guess (2 minutes)

Edit the same memory differently on both machines, then sync both:

```powershell
Add-Content "$a\claude\projects\demo\memory\demo-lesson.md" "`nEdited on A."
Add-Content "$b\claude\projects\demo\memory\demo-lesson.md" "`nEdited on B."

.\scripts\sync-ai-shared.ps1 -Mode Sync @common
.\scripts\sync-ai-shared.ps1 -Mode Sync @commonB

Get-Content "$demo\vault\sync\sync-log-DEMO-B.md"
```

The log reports a conflict and lists the path. **Neither file was modified.** It will stay
that way until you resolve it — no automatic merge, no last-writer-wins.

Try the collision guard too, which is what stops two machines quietly sharing one identity:

```powershell
.\scripts\sync-ai-shared.ps1 -Mode Sync @commonB -MachineKey 'DEMO-A'
```

It stops with an error instead of adopting machine A's baseline.

---

## 6. Delete it (10 seconds)

```powershell
Remove-Item "$env:TEMP\dotori-demo" -Recurse -Force
```

Nothing outside that folder was touched. No hooks were installed, no settings file edited,
nothing left in your real vault or runtime folders.

---

## What you just saw

| | |
|---|---|
| One source, many runtimes | Markdown agent converted to another runtime's format automatically |
| Two machines, one folder | Memory crossed over without either reading the other's state |
| Conflicts stop, they do not merge | The one case where guessing loses work |
| Identity is checked, not assumed | Two machines cannot silently share one key |

If you want this for real, go back to [the install steps](../README.md#install) — starting
with `-Mode Report`, same as here, but pointed at your actual folders.

**It is worth doing this on a single machine even if you only have one.** Two agent
runtimes sharing one set of skills and agent definitions is most of the value, and it does
not need a second computer.
