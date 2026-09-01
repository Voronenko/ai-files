# ai-files skills add

Installs Claude Code skills from a git repository.

Project mode (default) installs into `.ai-files/skills/` of the current
directory, records each skill in `skills-lock.json` (vercel-labs compatible),
and links it into the agent skill directories (`.claude/`, `.kilo/`,
`.opencode/`, `.agents/`) via `ai-files-skill-enable`. Global mode (`-g`)
installs into `~/.claude/skills/` and is **not** recorded in the lock.

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
| `-g`, `--global` | Target `~/.claude/skills/` instead of `$PWD/.ai-files/skills/`; no lock entry, no agent links |
| `-y`, `--yes` | Non-interactive: skip prompts, auto-skip already-installed skills |
| `-m`, `--method symlink\|copy` | **Global mode only.** Project installs are always real directories under `.ai-files/skills/` |
| `-h`, `--help` | Help |

## Discovery

Priority scan (`skills/`, `skills/.curated/`, `.experimental/`, `.system/`,
repo root — depth 2), falling back to a depth-5 recursive search that skips
`node_modules/`, `dist/`, `build/`, venvs. A skill is any `SKILL.md` with
non-empty frontmatter `name:` and `description:` (parsed via `yq`). Skills
with `metadata.internal: true` are excluded unless `INSTALL_INTERNAL_SKILLS=1`.

## Installation

Project mode fetches each selected skill into `.ai-files/skills/<sanitized>/`,
then:

1. records it in `skills-lock.json` at the git root (source, `skillPath`,
   `computedHash` — see `ai-files-skills-lock`), and
2. links it into the four agent dirs via `ai-files-skill-enable`.

If the ai-files scripts live outside the current repository, agent linking is
skipped with a warning naming the exact `ai-files skill enable <name>` command
to run instead; the install and lock entry still succeed.

Fetch engine (project mode): `gh skill install <spec> <path> --dir …` when the
`gh` CLI has skills support, otherwise a plain copy from the already-cloned
repository. `AI_FILES_SKILLS_ENGINE=gh|git|auto` overrides (default `auto`).

Global mode keeps the original methods: **symlink** (default — copy to
`~/.cache/skills/<name>`, link from the target dir, fall back to copy) or
**copy**.

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
ai-files-skills-add file://"$PWD"/fixtures/repo --all --yes
```

Environment: `INSTALL_INTERNAL_SKILLS=1`, `SKILLS_CLONE_TIMEOUT=<seconds>`,
`AI_FILES_SKILLS_ENGINE=gh|git|auto`.

Requires: `git`, `yq`; optional `fzf`, `gh` (with skills support).
