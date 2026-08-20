---
description: Manage Architecture Decision Records (ADRs) — router for /adr <subcommand>
---

Dot-form aliases delegate to the **adr-tools** skill. Available subcommands:

| Subcommand | Action |
|---|---|
| `/adr init [dir]` | Initialize the ADR repo (default `doc/adr`) |
| `/adr new "<Title>"` | Create a new ADR |
| `/adr list` | List all ADRs |
| `/adr link <SOURCE> <LINK> <TARGET> <REVERSE-LINK>` | Link two ADRs |
| `/adr generate toc\|graph` | Generate TOC or graph |
| `/adr help [cmd]` | Show usage |

Full reference: `skills/adr-tools/commands.md`.
