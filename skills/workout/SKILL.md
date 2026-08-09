---
name: workout
description: Use when managing coding workout sessions — start, update, end, show current, list sessions, view help, or load Memory Bank context. Router invoked as /workout <subcommand> (start, update, end, current, list, help, memory).
argument-hint: "[start|update|end|current|list|help|memory] [subject/notes]"
---

# Workout Session Router

Invoked as `/workout <subcommand> [args...]`. Dot-form aliases (`/workout.start`, `/workout.end`, … `/workout-memory.on`) delegate here via command shims pointing at the same resources.

## How to route

1. Take the FIRST whitespace-separated token of your arguments. Lowercase it; strip a leading dot if present (`.start` → `start`).
2. Look it up in the dispatch table below.
3. Read the matching resource file and execute its instructions verbatim.
4. Everything AFTER the subcommand token is the subject/notes — pass it as `$ARGUMENTS` to that resource.
5. Empty or unknown subcommand → read and follow `references/help.md`.

## Dispatch table

| Subcommand | Resource | Purpose |
|---|---|---|
| `start` | `references/start.md` | Begin a new workout session |
| `update` | `references/update.md` | Append progress to the current session |
| `end` | `references/end.md` | Summarize and close the current session |
| `current` | `references/current.md` | Show active session status |
| `list` | `references/list.md` | List all sessions |
| `help` | `references/help.md` | Show available commands |
| `memory` | `references/memory.md` | Load Memory Bank context (memory on) |

Shared state lives under `.ai-files/sessions/`; the active-session pointer is `.ai-files/sessions/.current-session`. External dependencies: the `repo-memory` MCP server and the `ai-files` CLI (`obsidian-add`).
