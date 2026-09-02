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

**Compatibility model (matches vercel-labs exactly)**: lock keys are raw
frontmatter skill names (`"Fancy.Pkg!"`); installed directories are
`sanitizeName(key)` — lowercase, runs of `[^a-z0-9._]+` → `-`, leading/
trailing `[.-]` stripped, 255 cap, `unnamed-skill` fallback → `fancy.pkg`.
Every key↔directory mapping goes through the same sanitize (the `dir`
subcommand exposes it), which is what their remove/discovery does — and
because it is idempotent, locks written by older ai-files versions (sanitized
keys) keep working with no migration.

`sourceType`: `github` (shorthand/URL → `owner/repo`, no `sourceUrl`),
`gitlab` (gitlab.com URL incl. subgroups and `/-/tree/<ref>` → canonical
`.git` URL in `source`+`sourceUrl`), `git` (SSH, GitHub Enterprise, any other
git host — raw URL in both), `local`, and `well-known` (any other `https://`
host not ending `.git` → hostname as `source`, full URL as `sourceUrl`, no
`wellKnownDigest`). `#ref` fragments and `/tree/<ref>` URLs populate `ref`.
Two skills whose names sanitize to the same directory collide on disk with a
warning — last install wins, matching vercel behavior.

**Remaining divergences** (deliberate, all tolerated by their reader):
`wellKnownDigest` and `subagents` are never produced; the `download`
sourceType is never produced (they never lock those either).

**Native interop** (validated by `tests/test-skills-interop-vercel.sh`,
both directions): the vercel-labs `skills` CLI reads this lock and restores
from it (`npx skills experimental_install`) — including entries whose raw
name differs from their directory; and locks written by their `add` are
consumed by `ai-files-skills-install`. Note their CLI exits 0 even when an
install fails, and its rewrites key entries by frontmatter name, so both key
spellings may coexist after mixed usage — both tools read either fine.

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
| `dir <name>` | Print the sanitized directory name for a skill name (vercel `sanitizeName`) |

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
