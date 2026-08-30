---
tags: [guide]
domain: dev
---

# Working guide - dev

> The router reads this file when it decides a request is development work.
> Budget: 60 lines. If it grows past that, something belongs in a domain core instead.

## Not this domain

| Work | Goes to |
|---|---|
| Naming standards, specifications | standards domain |
| Fiction, essays, posts | writing domain |

## Sub-domains

| Signal | Read |
|---|---|
| embedded, firmware | `embedded/GUIDE.md` -> `embedded/CORE.md` |
| web services | `web/GUIDE.md` |
| anything else | `CORE.md` alone |

**Universal laws are always in `CORE.md`.** A sub-domain core adds to it, never replaces it.

## Starting work

- Read `CORE.md` before touching a new tool or adapter
- New tools start with `git init` and a `.gitignore` for local configuration
- Keep deployment-specific values in config, not in source

## Finishing

- Session wrap-up writes to the project log, never to the code folder
- Periodic audit checks for missing, bloated, stale, and duplicated documents
