# ai-files skills explore

Explores a git repository and emits a [gilt](https://github.com/fsspec/gilt)-style
config mapping every discovered skill (and agent file) to vendor directories.
No installation happens — the output is a YAML snippet for later vendoring.

```bash
ai-files-skills-explore <REPO_SOURCE> [OPTIONS]
```

## Options

| Option | Description |
|---|---|
| `-b`, `--branch <ref>` | Branch/tag to clone (default `main`; falls back to the repo's default branch when the ref is missing) |
| `-o`, `--output <file>` | Write config to file instead of stdout |
| `-h`, `--help` | Help |

Sources accept the same forms as `skills add` (shorthand, HTTPS, SSH,
`file://`, local directory).

## Discovery rules

Same skill scanner as `skills add` (priority dirs → recursive fallback,
frontmatter via `yq`, internal skills filtered unless
`INSTALL_INTERNAL_SKILLS=1`). Additionally scans agent files (`*.md`) in
`agents/`, `commands/`, and `.claude/agents/` (depth 2).

Skill and agent names are sanitized for directory use: lowercased, non
`a-z0-9` folded to `-`, collapsed/trimmed hyphens.

Duplicate discoveries are de-duplicated (the root scan overlaps the priority
directories). A `SKILL.md` at the repository root maps to `src: .`.

## Output shape

```yaml
---
giltDir: ~/.gilt/clone
debug: false
parallel: true

repositories:
  # ai-files skills explore <REPO_SOURCE>
  - git: git@github.com:owner/repo.git   # https github URLs convert to ssh form
    version: <detected branch>
    sources:
      - src: skills/some-skill
        dstDir: vendor/skills/some-skill
      - src: commands/deploy-helper.md
        dstDir: vendor/agents/deploy-helper
```

Progress messages go to stderr; the config itself goes to stdout (or the
`--output` file).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Config produced |
| 1 | Invalid repository source |
| 2 | Missing `git`/`yq`, bad options |
| 4 | Clone failure |
| 5 | No skills or agents found |

## Unattended examples

```bash
ai-files-skills-explore owner/repo > gilt.yaml
ai-files-skills-explore owner/repo -b v1.0 -o gilt.yaml
INSTALL_INTERNAL_SKILLS=1 ai-files-skills-explore file://"$PWD"/fixtures/repo
```

Environment: `INSTALL_INTERNAL_SKILLS=1`, `SKILLS_CLONE_TIMEOUT=<seconds>`.

Requires: `git`, `yq`.
