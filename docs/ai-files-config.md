# ai-files config

`ai-files config` manages per-repository ai-files settings stored in the
**local git config** under the `aifiles.*` section. Nothing outside
`.git/config` is touched, so configuration is naturally per-checkout and never
committed.

```bash
ai-files config <command> [args]
```

## Storage

| Key | Meaning |
|---|---|
| `aifiles.vault` | Default Obsidian vault name |
| `aifiles.project-slug` | Project slug used to build vault paths (`myorg/myapp`) |
| `aifiles.vault-default-path` | Default folder path inside the vault (typically `pages/<slug>/repo-<name>`) |
| `aifiles.vault-session-default-path` | Session folder; defaults to `<vault-default-path>/sessions` |
| `aifiles.vault-memory-default-path` | Memory folder; defaults to `<vault-default-path>/memory` |

## Commands

| Command | Description |
|---|---|
| `setup [options]` | Setup wizard — interactive, or fully unattended with options (see below) |
| `list` | Print every `aifiles.*` value plus `NOT SET` hints for derived defaults (default command) |
| `get <key>` | Print one value; exit 1 when unset |
| `set <key> <value>` | Write a value (rejects unknown keys) |
| `unset <key>` | Remove a key |

The repository name used in path proposals is taken from the `origin` remote
URL (`.git` suffix stripped, both `https://…/org/repo.git` and
`git@host:org/repo.git` handled); without a remote, path proposals that need a
name are skipped.

## Interactive setup

`ai-files config setup` walks through vault selection (via `obsidian vaults
verbose`), project-slug picking (fzf over `<vault>/pages/` when available),
and the three path keys with `Y/n/<value>` prompts. Existing values are shown
first and kept unless confirmed otherwise.

Requires: `obsidian` CLI (configured), optional `fzf`.

## Unattended setup

Any option — or `-y` — switches setup into **non-interactive mode**: no
prompts, no fzf, and `obsidian` is never required (it is only consulted, when
installed, to soft-warn about unknown vault names). This makes the wizard
usable in scripts, CI, and bulk onboarding.

```bash
# Fully explicit:
ai-files config setup \
  --vault my-vault \
  --project-slug myorg/myapp \
  --vault-default-path "pages/myorg/myapp/repo-backend" \
  --vault-session-default-path "pages/myorg/myapp/repo-backend/sessions" \
  --vault-memory-default-path "pages/myorg/myapp/repo-backend/memory"

# Minimal — everything else derived from the origin remote:
ai-files config setup --vault my-vault

# Take all proposals for an already-configured repo:
ai-files config setup -y
```

Derivation rules when an option is omitted:

- `project-slug`: keeps the stored value, else skipped with a notice.
- `vault-default-path`: `pages/<slug>/repo-<name>`, or `pages/repo-<name>`
  without a slug; skipped entirely when no remote name is available.
- `vault-session-default-path`: `<vault-default-path>/sessions`.
- `vault-memory-default-path`: current value if already set, else
  `<vault-default-path>/memory`.

Exit status is non-zero when unattended mode cannot proceed — e.g. neither
`--vault` nor a stored `aifiles.vault` exists.

## Programmatic use

```bash
ai-files config get vault || echo "not configured"
vault=$(ai-files config get vault)
ai-files config set project-slug myorg/myapp
```

`get` returns exit code 1 with empty output for unset keys, which composes
safely with `||` fallbacks in scripts.

## Related

- `bin/ai-files-setup` step 2 offers `ai-files config setup` during repository
  onboarding.
- `tests/test-config.sh` covers list/get/set/unset plus both interactive-free
  setup modes.
