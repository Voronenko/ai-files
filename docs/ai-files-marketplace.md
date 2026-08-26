# ai-files marketplace

`ai-files marketplace` manages the Claude Code skill marketplaces published by
this repository. It is a thin dispatcher that routes to two sibling scripts:

```bash
ai-files marketplace <command> [options]
```

## Commands

| Command | Script | Purpose |
|---|---|---|
| `install` | `bin/ai-files-marketplace-install` | Register the ai-files marketplace (and optionally the vendor skills marketplace) with Claude Code |
| `update`  | `bin/ai-files-marketplace-update`  | Regenerate `.claude-plugin/marketplace.json` from the local `skills/` directory |

Unknown commands exit with status 1 and print the valid command list. Both
subcommands accept `-h/--help`.

## Typical flow

1. Add or adjust skills under `skills/` (or grouping in
   `bin/ai-files-marketplace-update`).
2. Run `ai-files marketplace update` and commit the regenerated
   `.claude-plugin/marketplace.json`; push so the GitHub source stays current.
3. Run `ai-files marketplace install --yes --scope project` on machines that
   should consume the marketplace.

## Related

- [ai-files-marketplace-install](./ai-files-marketplace-install.md)
- [ai-files-marketplace-update](./ai-files-marketplace-update.md)
- `tests/test-marketplace.sh` — integration suite covering unattended flows.
