# Projects

Working context for a project an agent picks up across several sessions. One file or one
folder per project.

## Against the human vault

| | `projects/` (here) | The human vault's project records |
|---|---|---|
| Nature | state, so an agent can resume | records a person keeps |
| Lifetime | cleaned up when the work ends | permanent |
| Example | "here is where it stands, next is X" | design decisions, development logs |

**Do not keep the same content in both.** The real record belongs to the human vault. What
lives here is a pointer to it plus the state that has not yet become a document.

Duplicating is tempting and always ends the same way: the two copies drift, and nothing
tells you which is current.

## Against `memory/project/`

- `memory/project/` — **reusable knowledge** gained from a project. Has a lifecycle.
- `projects/` — the project's **current working state**. Has no lifecycle; it is deleted
  when the work is done.

"The exporter corrupts already-converted input" is memory. "Batch mode is fixed, single
mode is not" is project state.

## Start empty

Do not pre-create files here. Add one when a piece of work actually spans sessions.

Empty placeholder files are worse than an empty folder — they read as something that
exists, so people look for content in them and conclude the system is broken.
