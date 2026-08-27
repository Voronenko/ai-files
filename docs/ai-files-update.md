# ai-files update

Keeps a repository's ai-files-managed directories in sync and links them into
per-agent folders. Five subcommands share global options; each also accepts
them after the subcommand name.

```bash
ai-files update <subcommand> [options]
```

## Subcommands

| Subcommand | Purpose |
|---|---|
| `files` | Sync `.ai-files/`, `.claude/`, `.kilo/`, `.opencode/`, `.agents/` from a distribution directory (default: the install's `dist/`, overridable with `-s`) |
| `link-claude` | Create `.claude/` mirroring `.ai-files/dotclaude/` (files become relative symlinks) |
| `link-kilo` | Same for `.kilo/` from `dotkilo/`, plus `agents/` + `rules/` linking |
| `link-opencode` | Same for `.opencode/` from `dotopencode/`, plus `agents/`, `rules/`, and `commands/` linking |
| `link-specify` | Create real `.specify/` dir; children of `dotspecify/` are linked — except `memory/`, which is copied once and then strictly local |

## Options (all subcommands)

| Option | Description |
|---|---|
| `-y`, `--yes` | Auto-confirm every prompt — **unattended mode** |
| `-d`, `--dry-run` | Preview only. Note: previews of modified files still prompt unless combined with `-y`; use `-d -y` for non-interactive previews |
| `-v`, `--verbose` | Verbose output |
| `-s, --source DIR` (`files` only) | Distribution source directory |
| `-h`, `--help` | Per-subcommand help |

Global options may appear before the subcommand
(`ai-files update -y link-claude`) or after it.

## `files` semantics

- rsync-based copy **without** `--delete`: files that exist only in the target
  are never removed automatically — they are reported as
  `rm "<path>"` suggestions in the summary.
- Modified files: git-tracked files are **always skipped** (even with `-y`;
  interactive mode can override per file); untracked files are overwritten
  under `-y`, prompted otherwise (`y/N/a/q`, `a` = yes-to-all).
- Never touched: `.ai-files/sessions|memory|memory-bank`, `memory.db*`, and
  tool runtime artifacts (`node_modules`, `package.json`,
  `package-lock.json`, `.gitignore` under `.opencode/`/`.kilo/`).
- Managed symlinks (`<target> -> .ai-files/dot*`) are replicated rather than
  copied; merge folders (`commands`, `hooks`, `skills`, `rules`) preserve
  nested symlinks.
- Missing agent dirs are detected and the matching `link-*` commands are
  suggested at the end.

## `link-*` semantics

- Every file under the source dot-folder becomes a **relative** symlink in the
  agent dir; nested symlinks are re-resolved to their absolute targets first
  (`.ai-files/dotclaude/x -> ../../VERSION` becomes
  `.claude/x -> .ai-files/VERSION`).
- Agents/skills/rules are linked from `.ai-files/`:
  - skills link only the **default skills** list — `default_skills.yaml` at
    the repo root (yq or grep parsing, hardcoded fallback otherwise);
    vendored `namespace/skill` entries link under the bare name, gaining a
    `-namespace` suffix only when the bare name collides across the skill
    inventory.
  - `link-kilo` skips individual skill linking when `.kilo/skills` is itself a
    symlink, and warns when a previous run left symlinks inside
    `.kilo/node_modules`.
  - `link-opencode` additionally links `.ai-files/commands/` (opencode has no
    dot-folder commands of its own).
- Conflicts (wrong-target symlinks, real occupants) are replaced under `-y`,
  prompted otherwise. Target-only files are reported as removal candidates,
  excluding managed subtrees (`agents/`, `skills/`, `rules/`, `commands/`)
  and runtime artifacts.

## `link-specify` semantics

`.specify/` is a **real** directory whose children are symlinks into
`.ai-files/dotspecify/`. The `memory/` child is per-project state: copied once
if missing, never overwritten afterwards — local edits are safe. A legacy
`.specify` single symlink is migrated to the real-directory layout (prompted,
or automatic with `-y`).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (including interactive quits via `q`) |
| 1 | Not in a git repo; missing dot-folder source (run `files` first); bad option; missing `--source` value |

Note: when `detect_git_root` fails, `set -e` exits before the friendly error
prints — the exit code is still 1.

## Unattended examples

```bash
ai-files update files -s ./dist -y            # sync from custom dist
ai-files update files -s ./dist -d -y         # non-interactive preview
ai-files update -y link-claude                # globals before subcommand
ai-files update link-kilo -y
ai-files update link-opencode --dry-run -y
ai-files update link-specify -y
```

Requirements: `git`, `rsync`; `python3` (cosmetic relative-path display with
fallback) and `yq` (skills-list parsing with grep fallback) are optional.

## Related

- `tests/test-update.sh` — unattended coverage for all five subcommands via a
  fixture dist and throwaway git repos.
- `bin/ai-files-setup` orchestrates these subcommands during onboarding.
