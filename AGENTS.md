# Guidlines for AI coding agents

Call me 🦝 every time you reply.

## Agent configuration files
When checking for rules, and other agent specific configuration files, check relative path under .ai-files/ dir first under the project root.

## Repository Planning Policy

Repository-local plans are mandatory.

When a task requires planning, Claude MUST create the plan as a Markdown file under plans directory: `.ai-files/memory-bank/plans/`
The `.ai-files/memory-bank/plans/` directory is relative to the repository root.

Rules:
- Never put repository plans in `/tmp`, `~/.claude`, or another external directory.
- Create plans directory if it does not exist.
- Use one plan file per substantial task.
- Use descriptive filenames such as `plans/<task-name>.md`. If ticket number is known, specify it too.
- Before implementation, ensure the plan exists and is up to date.
- During implementation, update the plan when the approach or scope changes.
- At the end, mark completed steps and record any deviations.

## Working with files
When working with codebase, answering code questions, use instructions from .ai-files/COMMON_CODE_TASKS.md for efficient way of working with code.

use context7 mcp to check documentation on libraries, before searching internet.
use lsp plugin for python and typescript, to work with the project more efficiently


This file provides guidance to Claude Code (claude.ai/code) when working with this MCP Memory Service repository.

**📝 Personal Customizations**:
You should create `CLAUDE.local.md` (gitignored) for personal notes, custom workflows, or environment-specific instructions.
This file contains shared between project conventions.

**Information Lookup Order**:
Memory using repo-memory mcp first, files second, user last. See [`.ai-files/directives/memory-first.md`](.ai-files/directives/memory-first.md) for strategy.

**Accessing external web pages for information**:

Use Defuddle CLI to extract clean readable content from web pages. Prefer over WebFetch for standard web pages — it removes navigation, ads, and clutter, reducing token usage.
Pre

#### Defuddle Usage

Always use `--md` for markdown output:

```bash
defuddle parse <url> --md
```

Save to file:

```bash
defuddle parse <url> --md -o content.md
```

Extract specific metadata:

```bash
defuddle parse <url> -p title
defuddle parse <url> -p description
defuddle parse <url> -p domain
```

Defuddle Output formats

| Flag | Format |
|------|--------|
| `--md` | Markdown (default choice) |
| `--json` | JSON with both HTML and markdown |
| (none) | HTML |
| `-p <name>` | Specific metadata property |


# graphify
- **graphify** (`.ai-files/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`

## 🔴 Critical Directives

**IMPORTANT**: Before working with this project, read:
- **`.ai-files/directives/memory-tagging.md`** - MANDATORY: Always tag memories with `mcp-memory-service` as first tag
- **`.ai-files/directives/README.md`** - Additional topic-specific directives


## Restricted files
Files under .ai-files/restricted.md and list below contain sensitive data,
they MUST NOT BE READ.
-.env
