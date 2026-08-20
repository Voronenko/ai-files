---
name: adr-tools
description: Use when documenting architecture decisions, managing Architecture Decision Records (ADRs), or recording significant technical choices. Drives the adr-tools CLI (installed at /home/slavko/dotfiles/adr) to init, create, link, list, and generate ADRs. Triggers: "record this decision as an ADR", "ADR this", "why did we choose X", "let's go with X", "we decided to", architecture decision, ADR.
---

# ADR Tools

## Overview

Architecture Decision Records (ADRs) are short documents that capture a single significant decision — what was decided, why, and the consequences. They explain to future maintainers why the code is shaped the way it is.

This skill drives the **adr-tools CLI** (`adr`, installed at `/home/slavko/dotfiles/adr`). The CLI owns the ADR files: numbering, filenames, status links, and the index. The agent's job is to detect decisions and write good content, not to manage files by hand.

## Core Rules

1. **Only the `adr` CLI creates, numbers, links, or lists ADR files.** Never hand-create a `NNNN-title.md`, never edit `.adr-dir` manually, never renumber or rename an existing ADR.
2. **The only file you edit directly is the draft `adr new` just produced** — it prints the path and opens it in the editor. Fill in Context / Decision / Consequences there.
3. **Accepted ADRs are never edited.** To change a decision, supersede it (`adr new -s N`). To add a relationship, use `adr link`.
4. **One decision per ADR.** Keep it short — readable in about 2 minutes.

## When to Activate

**Explicit signals:**
- "Record this decision as an ADR" / "ADR this"
- "Let's go with X" / "We should use X instead of Y"
- "The trade-off is worth it because..."
- "We decided to..." / "The reason we're doing X instead of Y is..."
- "Why did we choose X?" (→ read existing ADRs)

**Implicit signals** — suggest an ADR, but confirm before creating:
- Comparing two frameworks or libraries and reaching a conclusion
- A schema / datastore choice with stated rationale
- Choosing between architectural patterns (monolith vs microservices, REST vs GraphQL)
- Auth/authz strategy, deployment/infrastructure selection

**Do not record:** implementation details, naming conventions, trivial optimizations, temporary workarounds.

## Workflow: Capturing a New ADR

1. **Initialize (first time only)** — run `adr list`. If it fails ("directory does not exist"), run `adr init [DIRECTORY]` (defaults to `doc/adr`). This writes `.adr-dir` and seeds `0001-record-architecture-decisions.md`.
2. **Create the draft** — `adr new "<Title>"`. The CLI numbers it (`NNNN`), slugifies the title, fills the template with `Status: Accepted`, opens the editor, and prints the new path.
3. **Write the content** — edit that draft: a specific Decision, the Context (problem + constraints), rejected Alternatives (pros / cons / why-not), and honest Consequences (positive / negative / risks). Add a confidence note if the decision was made under uncertainty.
4. **Link if relevant** — pass `-l "N:Amends:Amended by"` at creation, or run `adr link` afterwards.
5. **Supersede, never edit** — `adr new "<New title>" -s N` writes "Superceded by" into the old ADR and "Supercedes" into the new one.

## Quick Reference

| Operation | Command |
|---|---|
| Initialize | `adr init [DIRECTORY]` |
| New ADR | `adr new [-s N] [-l T:L:R] "<Title>"` |
| Link two ADRs | `adr link SOURCE LINK TARGET REVERSE-LINK` |
| List | `adr list` |
| Table of contents | `adr generate toc` |
| Graph (Graphviz) | `adr generate graph \| dot -Tsvg > graph.svg` |
| Help | `adr help [COMMAND]` |

Full reference: [commands.md](commands.md)

## ADR Format

`adr new` generates from this template:

```markdown
# NUMBER. TITLE

Date: DATE

## Status

STATUS

## Context

The issue motivating this decision, and any context that influences or constrains the decision.

## Decision

The change that we're proposing or have agreed to implement.

## Consequences

What becomes easier or more difficult to do and any risks introduced by the change that will need to be mitigated.
```

Enrich the draft while editing — a good ADR also records rejected alternatives and confidence:

```markdown
## Alternatives Considered

### Alternative 1: [Name]
- **Pros**: ...
- **Cons**: ...
- **Why not**: ...

## Consequences
### Positive
- ...
### Negative
- ...
### Risks
- [risk and mitigation]
```

**Confidence**: add a line like `**Confidence**: high | medium | low — [what would change this]` when relevant.

## Status Values

- **Accepted** — current active decision (default set by `adr new`)
- **Supercedes / Superceded by** — written by `adr new -s` into the new / old ADR respectively (note: the tool spells it with one "d")
- Relationship links (`Amends`, `Depends on`, `Relates to`, ...) also live in the Status section

## Linking ADRs

Relationships are free-form labels written into each ADR's Status section:
- **Supersedes / Superceded by** — decision replacement (`adr new -s N`)
- **Amends / Amended by** — modification (`adr link 12 Amends 10 "Amended by"`)
- **Depends on / Required by** — dependency (`adr link SOURCE "Depends on" TARGET "Required by"`)
- **Relates to / Related to** — general reference

## Directory Discovery

The CLI locates the ADR directory by walking up from the current directory:
1. `.adr-dir` file (written by `adr init <dir>`)
2. `doc/adr` directory
3. Falls back to `doc/adr`

## Best Practices

1. **Be specific** — "Use Prisma ORM", not "use an ORM".
2. **Record the why** — rationale matters more than the what.
3. **Include rejected alternatives** — future developers need to know what was considered.
4. **State consequences honestly** — every decision has trade-offs.
5. **Use present tense** — "We use X", not "We will use X".
6. **Don't edit accepted ADRs** — supersede with a link instead; this keeps a clear log of how long each decision governed the work.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Documenting trivial choices | Only architectural decisions |
| Deleting or editing an accepted ADR | Mark as superseded via `adr new -s N` |
| Missing context / consequences | Complete all sections |
| Multiple decisions in one ADR | Split into separate records |
| Hand-creating ADR files | Always use `adr new` / `adr init` |
