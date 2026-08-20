---
description: Create a new Architecture Decision Record
---

Dot-form alias for the **adr-tools** skill.

Run `adr new <title> [options]` in the shell, where `$ARGUMENTS` is the decision title plus any options. The CLI numbers the ADR (`NNNN`), slugifies the title, sets `Status: Accepted`, opens the draft in the editor, and prints its path. Fill in Context / Decision / Consequences (including rejected alternatives and trade-offs) in the generated file only — never hand-create ADR files.

Options: `-s N` (supersede ADR N), `-l TARGET:LINK:REVERSE-LINK` (link at creation). See `skills/adr-tools/commands.md`.
