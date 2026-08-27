# ai-files skill enable

Creates symlinks that expose a skill from the ai-files library to coding
agents. Fully parameterized — no prompts, safe for scripts.

```bash
ai-files skill enable <skill-name> [OPTIONS]
```

## Skill resolution (first match wins)

1. Exact qualified path under `.ai-files/skills/<name>` (handles top-level and
   nested, e.g. `ag-kit/brainstorming`)
2. `.ai-files/dotclaude/skills/<name>`
3. Recursive leaf-name search; a single hit is used, multiple hits abort with
   the qualified candidates

An unknown skill prints the available list (including a tip about qualified
paths) and exits 1.

## Options

| Option | Description |
|---|---|
| `--claude-only` | Link only into `.claude/skills/` |
| `--kilo-only` | Link only into `.kilo/skills/` |
| `--opencode-only` | Link only into `.opencode/skills/` |
| `--agents-only` | Link only into `.agents/skills/` |
| `-h`, `--help` | Help |

The `--*-only` flags are mutually exclusive. Without them all four targets are
processed; missing target directories are created.

## Link semantics

- Symlinks are **relative** (`realpath --relative-to`), so the project stays
  relocatable.
- Existing correct link ⇒ `Already enabled` (no churn, still exit 0).
- Existing symlink pointing elsewhere ⇒ replaced.
- Broken symlink ⇒ repaired.
- A real file/dir occupying the target path ⇒ error (exit 3), never overwritten.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Enabled (or already enabled) |
| 1 | Skill not found / ambiguous |
| 2 | Target directory not writable |
| 3 | Bad usage or conflicting target path |

## Examples

```bash
ai-files skill enable adr-tools
ai-files skill enable ag-kit/brainstorming --claude-only
ai-files skill enable lnav --agents-only
```
