# Context routing

An agent that reads everything you know before every task is slow, expensive, and less
accurate than one that reads the right five files. Routing decides which files those are.

This is the oldest working piece of the system and the one most worth copying.

## The shape

```
user request
     |
     v
router          one small file. Decides the domain. Nothing else.
     |
     v
domain guide    per-domain working instructions
     |
     v
domain core     laws that apply to that domain
     |
     v
project docs    the specific thing being worked on
```

Each layer names the next. No layer restates the layer above it.

## The router

The router's entire job is to answer "what kind of work is this, and what should be read
because of it". It contains a table and a short list of universal rules:

```markdown
| Signal                        | Domain   | Read                          |
|-------------------------------|----------|-------------------------------|
| fiction, essays, blog posts    | writing  | writing/GUIDE.md              |
| code, scripts, add-ins, apps   | dev      | dev/GUIDE.md -> dev/CORE.md   |
| standards, naming rules        | domain-c | domain-c/GUIDE.md             |
```

**Keep it small.** A budget of roughly 30 lines is enough, and the limit is the point: the
moment domain-specific rules start accumulating in the router, every task pays to read
rules that belong to one domain.

**One router.** Putting a `CLAUDE.md` in several folders looks tidy and fails quietly —
the ones outside the working directory are never loaded, so they become documents that
describe behavior nobody gets. Keep a single router at a path the runtime always reads,
and let it point outward.

## Domain guides

One per domain, describing how work in that domain is done and routing further if the
domain has sub-areas. A guide answers:

- What is *not* this domain (with a pointer to where it belongs)
- What to read before starting
- What to do when finishing

## Domain cores

Accumulated laws — the things learned the hard way, each one attached to the domain it
applies to. Rules that apply everywhere stay in a global core; a domain core never
replaces it, it adds to it.

Splitting cores per domain is what makes selective reading possible. Before the split,
"read the accumulated knowledge" meant reading all of it regardless of the task.

## Rules that keep routing honest

**Re-read the file; do not recall it.** If a guide or standard is relevant, open the
current version. A summary from an earlier session describes the file as it was.

**Point, do not copy.** When two documents state the same rule, they will disagree
eventually, and nothing tells you which one is stale. Give every rule exactly one owner
and link to it.

**Route before reading, not after.** Deciding the domain first is what keeps the context
small. Reading first and classifying afterwards has already spent what routing saves.
