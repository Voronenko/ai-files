# Guidlines for AI coding agents

Call me 🦝 every time you reply.

## Agent configuration files
When checking for rules, and other agent specific configuration files, check relative path under .ai-files/ dir first under the project root.

## Working with files
When working with codebase, answering code questions, use instructions from .ai-files/COMMON_CODE_TASKS.md for efficient way of working with code.

use context7 mcp to check documentation on libraries, before searching internet.
use lsp plugin for python and typescript, to work with the project more efficiently


This file provides guidance to Claude Code (claude.ai/code) when working with this MCP Memory Service repository.

**📝 Personal Customizations**:
You can create `CLAUDE.local.md` (gitignored) for personal notes, custom workflows, or environment-specific instructions.
This file contains shared project conventions.

**Information Lookup**:
Files first, memory second, user last. See [`.ai-files/directives/memory-first.md`](.ai-files/directives/memory-first.md) for strategy.
Comprehensive project context stored in memory with tags `claude-code-reference`.

**Accessing external web pages for information**:

Use Defuddle CLI to extract clean readable content from web pages. Prefer over WebFetch for standard web pages — it removes navigation, ads, and clutter, reducing token usage.

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
