# ai-files marketplace update

Generates `.claude-plugin/marketplace.json` from the local `skills/`
directory. Pure function of the working tree — no prompts, no network — and
safe to run repeatedly (idempotent output).

```bash
ai-files marketplace update
```

## Requirements

- Python 3 with **PyYAML** (`python3 -m pip install pyyaml`). The CI workflow
  installs it before running the test suite.

## How plugins are derived

1. Every directory under `skills/` containing a `SKILL.md` becomes a plugin
   entry, except names in `SKIP_SKILLS` (currently `a-template`, used as a
   template).
2. Plugin name = frontmatter `name:` from `SKILL.md` (fallback: directory
   name), prefixed with `ai-files-`. The prefix is idempotent — an
   already-prefixed name is not double-prefixed.
3. Description = frontmatter `description:`; when frontmatter is missing or
   invalid YAML, fallbacks are used (`Skills from <dir>` for descriptions) and
   generation never fails on a single malformed skill.

## Grouping

`SKILL_GROUPS` inside `bin/ai-files-marketplace-update` merges several skills
into one plugin:

| Plugin | Skills |
|---|---|
| `dev-swiss-knife` | adr-tools, mermaid, obsidian-cli, plantuml |
| `lnav` | lnav, lnav-unattended |

Group entries use the group's `description`; every skill not listed in a group
becomes its own individual plugin entry. Grouped skills carry their paths in
the plugin's `skills` array.

## Output

`.claude-plugin/marketplace.json` with:

- `$schema` — Claude marketplace schema URL
- `name: ai-files-skills` + description + owner block
- `plugins[]` — each `{name, source: "./", description, skills[]}`

The script prints a summary line per plugin after writing.

## Workflow

```bash
# after changing skills/
ai-files marketplace update
git add .claude-plugin/marketplace.json && git commit && git push
ai-files marketplace install --yes   # consumers re-register from GitHub
```

## Related

- [ai-files-marketplace-install](./ai-files-marketplace-install.md)
- `tests/test-marketplace.sh` — U-group cases cover grouping, prefixing,
  skip-list and invalid-frontmatter fallbacks via a fixture tree.
