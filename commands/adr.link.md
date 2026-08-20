---
description: Link two Architecture Decision Records
---

Dot-form alias for the **adr-tools** skill.

Run `adr link <SOURCE> <LINK> <TARGET> <REVERSE-LINK>` in the shell, where `$ARGUMENTS` are the four required positional args. Writes `<LINK>` into SOURCE's Status section and `<REVERSE-LINK>` into TARGET's. Example: `adr link 12 Amends 10 "Amended by"`. See `skills/adr-tools/commands.md`.
