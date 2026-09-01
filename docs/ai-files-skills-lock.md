# ai-files skills lock

Manages `skills-lock.json` — the committed manifest of external skills
installed into `.ai-files/skills/`. Python 3, standard library only.

```bash
ai-files-skills-lock [--dir <lockdir>] [--skills-dir <dir>] <COMMAND>
```

Defaults: lock dir = git root of the cwd, skills dir = `<lockdir>/.ai-files/skills`.

## Format (vercel-labs compatible)

Byte-compatible with `vercel-labs/skills` `src/local-lock.ts`:

```json
{
  "version": 1,
  "skills": {
    "skill-name": {
      "source": "owner/repo",
      "sourceType": "github",
      "skillPath": "skills/pdf/SKILL.md",
      "computedHash": "<sha256>"
    }
  }
}
```

- Keys sorted, 2-space indent, trailing newline, timestamp-free (merge-friendly).
- `sourceType`: `github` (shorthand `owner/repo`), `git` (any other git remote,
  keeps full URL + `sourceUrl`), `local` (absolute path, stored portably as
  `./x`, `../y` or `.` and re-absolutized on read).
- `computedHash`: SHA-256 over all files (symlinks, `.git/`, `node_modules/`
  excluded), sorted by relative path with a JS `localeCompare`-approximating
  collation, hashing `path` then raw content per file.
  Shell equivalent for cross-checking (GNU tools, locale-sensitive — pin
  `LC_ALL` for reproducibility):

  ```bash
  find "$dir" -type d \( -name .git -o -name node_modules \) -prune -o \
      -type f -printf '%P\0' |
    sort -z |
    while IFS= read -r -d '' f; do printf '%s' "$f"; cat "$dir/$f"; done |
    sha256sum
  ```

- Corrupt files (merge markers), `version < 1`, or missing `skills` read back
  as an empty lock — the tool self-heals on the next write.

**Divergence from vercel**: the lock key is the sanitized skill *directory*
name (not the frontmatter `name:`), because skill resolution works by
directory. `subagents`/`wellKnownDigest` fields are not produced.

## Commands

| Command | Description |
|---|---|
| `add <name> --source S [--skill-path P] [--ref R] [--hash H]` | Add/update an entry (hash from skills dir unless `--hash`) |
| `remove <name>` | Drop an entry (exit 1 if absent) |
| `list [--json]` | List entries |
| `missing` | Entries with no installed directory |
| `plan [--force]` | Pipe-separated rows for skills needing (re)install — consumed by `ai-files-skills-install` |
| `refresh` | Drop entries whose directory vanished; report hash drift |
| `init` | Audit `.agents/skills/`: repo-owned skills are skipped silently, unknown-origin skills are reported as `SKIPPED` with a re-add hint (origin is unrecoverable — re-add via `skills-add` to record it) |
| `hash <dir>` | Print the computed hash of a directory |

## Exit codes

0 on success; 1 when `remove` names an absent entry; 2 on usage errors.

## Unattended examples

```bash
ai-files skills lock list
ai-files skills lock missing
ai-files skills lock refresh
ai-files skills lock init
```

Prompt-free; safe in CI.
