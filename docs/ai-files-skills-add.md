# ai-files skills add

Installs Claude Code skills from a git repository into `.claude/skills/`
(project-local) or `~/.claude/skills/` (global).

```bash
ai-files-skills-add <REPO_SOURCE> [OPTIONS]
```

## Repository sources

- GitHub shorthand: `owner/repo`
- HTTPS: `https://github.com/owner/repo` (`.git` optional)
- SSH: `git@github.com:owner/repo.git`
- Local path or `file://` URL — resolved to an absolute path; useful for
  hermetic/offline runs and testing

The repository is shallow-cloned into a temp dir (cleaned up on exit).

## Options

| Option | Description |
|---|---|
| `-l`, `--list` | List discovered skills (table) without installing |
| `-s`, `--skill [<name>]` | Install specific skill(s); repeatable. Bare `-s` with fzf+TTY opens interactive selection. `-s '*'` ≡ `--all` |
| `-a`, `--all` | Install every discovered skill |
| `-g`, `--global` | Target `~/.claude/skills/` instead of `$PWD/.claude/skills/` |
| `-y`, `--yes` | Non-interactive: skip prompts, auto-skip already-installed skills |
| `-m`, `--method symlink\|copy` | Install method (default `symlink`) |
| `-h`, `--help` | Help |

## Discovery

Priority scan (`skills/`, `skills/.curated/`, `.experimental/`, `.system/`,
repo root — depth 2), falling back to a depth-5 recursive search that skips
`node_modules/`, `dist/`, `build/`, venvs. A skill is any `SKILL.md` with
non-empty frontmatter `name:` and `description:` (parsed via `yq`). Skills
with `metadata.internal: true` are excluded unless `INSTALL_INTERNAL_SKILLS=1`.

## Installation methods

- **symlink** (default): the skill directory is copied to the canonical store
  `~/.cache/skills/<name>` and linked from the target dir; falls back to copy
  if linking fails.
- **copy**: plain recursive copy into the target dir.

Already-installed skills: interactive `u/s` prompt, or automatic **skip** under
`--yes`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (including "no skills found" in list mode) |
| 1 | Invalid source / unknown skill |
| 2 | Missing args or prerequisites (`git`, `yq`), bad option |
| 3 | Target directory not writable |
| 4 | Clone failure |
| 5 | No skills found when installing |

## Unattended examples

```bash
ai-files-skills-add owner/repo --list
ai-files-skills-add owner/repo --skill frontend-design --yes
ai-files-skills-add owner/repo --all --global --yes
ai-files-skills-add file://"$PWD"/fixtures/repo --all --yes -m copy
```

Environment: `INSTALL_INTERNAL_SKILLS=1`, `SKILLS_CLONE_TIMEOUT=<seconds>`.

Requires: `git`, `yq`; optional `fzf`.
