# ai-files skills install

Restores the skills recorded in `skills-lock.json`: fetches missing ones into
`.ai-files/skills/`, links them into the agent skill directories via
`ai-files-skill-enable`, and re-stamps their lock hashes. Idempotent — present
skills whose hash matches the lock are skipped.

```bash
ai-files-skills-install [OPTIONS]
```

Run it on a fresh clone or after a `make build` wiped the gitignored
`.ai-files/skills/` content.

## Behavior

1. `ai-files-skills-lock plan` decides what needs (re)installation:
   entries whose directory is missing, or any entry with `--force`.
   Present-but-drifting skills (hash mismatch) are reported and skipped —
   `--force` reinstalls them and restores the pristine lock hash.
2. `local` / `node_modules` / `well-known` entries cannot be fetched remotely
   and are skipped with a notice.
3. Per skill: fetch (see engine below) → `ai-files-skill-enable` (links
   `.claude/`, `.kilo/`, `.opencode/`, `.agents/`) → lock re-stamp.

Fetch engine: `gh skill install <spec> <path> --dir … [--pin <ref>]` when the
`gh` CLI has skills support and the entry is github-sourced, otherwise one
shallow git clone per distinct source (shared across its skills) and a copy of
the `skillPath` directory. `AI_FILES_SKILLS_ENGINE=gh|git|auto` overrides
(default `auto`). Repo-root skills (`skillPath: "SKILL.md"`) are materialized
via `git archive` so no `.git` directory is copied.

## Options

| Option | Description |
|---|---|
| `-f`, `--force` | Reinstall even present skills (restores lock hashes) |
| `-y`, `--yes` | Accepted for symmetry; this command never prompts |
| `-h`, `--help` | Help |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (including "nothing to install") |
| 1 | At least one skill failed to install |
| 2 | Usage error |
| 3 | Cannot create `.ai-files/skills/` |

## Unattended examples

```bash
ai-files skills install          # restore missing locked skills
ai-files skills install --force  # reinstall everything, re-stamp hashes
```

Environment: `SKILLS_CLONE_TIMEOUT=<seconds>`, `AI_FILES_SKILLS_ENGINE=gh|git|auto`.

Requires: `git`; optional `gh` (with skills support).
