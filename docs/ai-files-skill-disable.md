# ai-files skill disable

Removes the symlinks created by `ai-files skill enable`, detaching a skill
from one or all agents. The underlying skill files under `.ai-files/` are
never touched. Fully parameterized — no prompts.

```bash
ai-files skill disable <skill-name> [OPTIONS]
```

## Skill resolution

Identical to `skill enable` (qualified path → dotclaude → leaf search with
ambiguity report). Unknown skills exit 1.

## Options

| Option | Description |
|---|---|
| `--claude-only` | Remove only from `.claude/skills/` |
| `--kilo-only` | Remove only from `.kilo/skills/` |
| `--opencode-only` | Remove only from `.opencode/skills/` |
| `--agents-only` | Remove only from `.agents/skills/` |
| `-h`, `--help` | Help |

The `--*-only` flags are mutually exclusive. Without them every agent dir is
processed.

## Removal semantics

A link is removed only when its **resolved target equals the skill source**
(readlink -f comparison) — unrelated symlinks in the same directory are never
touched. Absent directories and non-matching links report `Not linked in …`.

Not being linked anywhere is **not** an error: the tool exits 0 with a notice,
making disable idempotent for scripts.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Disabled, or nothing was linked |
| 1 | Skill not found / ambiguous |
| 3 | Bad usage or symlink removal failure |

## Examples

```bash
ai-files skill disable adr-tools              # everywhere it is linked
ai-files skill disable lnav --claude-only
ai-files skill disable ag-kit/brainstorming   # qualified path
```
