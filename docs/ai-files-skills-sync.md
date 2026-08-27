# ai-files skills sync

Enables every skill listed in the repository's `agents.yaml` across the agent
dot directories present in the project (`.claude/`, `.kilo/`, `.opencode/`).
Delegates per-agent linking to `ai-files-skill-enable`.

```bash
ai-files skills sync [--dry-run]
```

## agents.yaml

```yaml
default_skills:
  - adr-tools            # plain name or qualified path
  - ag-kit/brainstorming # nested skills use qualified paths
```

Only a top-level `default_skills:` list of `- ` items is read. When the file
is missing, the tool prints a ready-to-edit example derived from the symlinks
currently present in `.claude/skills/` and exits 2.

## Behavior

1. Parse and resolve each entry against `.ai-files/skills/` and
   `.ai-files/dotclaude/skills/` (exact qualified path first, then leaf-name
   search). Unresolvable entries warn; ambiguous leaf names ask for qualified
   paths.
2. For each present agent dir: already-correct symlink ⇒ `already enabled`;
   otherwise create it (or just print under `--dry-run`). Missing agent dirs
   are skipped with a notice.

`--dry-run` never touches the filesystem.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | All resolved skills synced (or nothing to do) |
| 1 | Partial success — one or more warnings (missing/ambiguous/failed) |
| 2 | `agents.yaml` missing or unknown option |

## Unattended examples

```bash
ai-files skills sync --dry-run
ai-files skills sync
```

Both are prompt-free; safe in CI.
