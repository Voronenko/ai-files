# ai-files skills remove

Removes a skill installed into `.ai-files/skills/`: unlinks it from the agent
skill directories, deletes the skill directory, and drops its `skills-lock.json`
entry.

```bash
ai-files-skills-remove <SKILL_NAME>
```

Steps run in this order (disable needs the source directory to resolve):

1. `ai-files-skill-disable <name>` — removes the symlinks in `.claude/`,
   `.kilo/`, `.opencode/`, `.agents/` (failures tolerated with a warning).
2. `rm -rf .ai-files/skills/<name>`.
3. `ai-files-skills-lock remove <name>` (absent entry is not an error).

Names are validated before use in the `rm -rf` path: empty, absolute, or
`..`-containing names are rejected.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Removed (dir and/or lock entry existed) |
| 1 | Nothing to remove — no skill directory and no lock entry |
| 2 | Usage error / invalid name |

## Unattended examples

```bash
ai-files skills remove frontend-design
```

Prompt-free; safe in CI.
