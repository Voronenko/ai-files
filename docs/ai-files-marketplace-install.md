# ai-files marketplace install

Registers the **ai-files skills marketplace** with Claude Code, optionally adds
the 3rd-party **vendor skills marketplace**, then lists what is registered.

```bash
ai-files marketplace install [OPTIONS]
```

## Prerequisites

- `claude` CLI on PATH (Claude Code). Missing ⇒ exit 1.
- A git checkout of this repository; an `origin` remote pointing at GitHub
  enables registration *by repo shorthand* (see below).

## Options

| Option | Description |
|---|---|
| `-y`, `--yes` | Non-interactive: answer yes to both registration prompts |
| `-s`, `--scope <scope>` | Claude installation scope: `project` (**default**), `user`, `local` |
| `-h`, `--help` | Show help |

An invalid or missing scope value exits 1 before touching anything.

## Marketplace source resolution

Step 1 registers the ai-files marketplace from the repository's GitHub
shorthand (`owner/repo`), derived from the `origin` remote. Supported URL
shapes (`.git` suffix stripped):

- `git@github.com:owner/repo.git`
- `https://github.com/owner/repo.git`
- `https://github.com/owner/repo`

When no GitHub remote can be derived (no origin, or a non-GitHub host), the
script falls back to registering the **local repository path** instead and
prints a warning.

Step 2 adds the vendor marketplace from a fixed raw.githubusercontent.com URL.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Everything requested succeeded (skipped prompts count as success) |
| 1 | Missing `claude` CLI, bad options/scope, **or any failed registration** |

Failed registrations are reported per-step (✗ on stderr) but do not abort the
remaining steps; the final exit code reflects whether anything failed, so
unattended runs can detect partial failure.

## Unattended usage

```bash
# Register both marketplaces into the project scope:
ai-files marketplace install --yes

# Explicit user scope:
ai-files marketplace install --yes --scope user

# Interactive (prompts; Enter accepts step 1, declines step 2 by default):
ai-files marketplace install
```

## Notes

- Run `ai-files marketplace update` first whenever `skills/` changed, commit
  and push, so the GitHub-hosted `marketplace.json` reflects reality.
- Registration is additive; re-running is safe.

## Related

- [ai-files-marketplace-update](./ai-files-marketplace-update.md) — regenerate
  `marketplace.json`.
