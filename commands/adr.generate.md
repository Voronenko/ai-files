---
description: Generate an ADR table of contents or dependency graph
---

Dot-form alias for the **adr-tools** skill.

Run `adr generate toc [options]` or `adr generate graph [options]` in the shell, where `$ARGUMENTS` is the report type and options. `toc` emits a markdown index; `graph` emits a Graphviz digraph (pipe to `dot`, e.g. `adr generate graph | dot -Tsvg > graph.svg`). See `skills/adr-tools/commands.md`.
