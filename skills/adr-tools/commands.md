# ADR Tools Command Reference

Detailed reference for the adr-tools CLI (`adr`, installed at `/home/slavko/dotfiles/adr`).

All commands are invoked through the shell as `adr <command>`. The agent must use these commands to manage ADR files — never create or edit ADR files by hand (except filling in the draft `adr new` produces).

## `adr init [DIRECTORY]`

Initialize an ADR repository in the current project.

- `DIRECTORY` (optional): where ADRs live. Defaults to `doc/adr`.

**What it does:**
- If `DIRECTORY` is given: `mkdir -p` it and writes a `.adr-dir` file recording the path.
- Creates the first ADR `0001-record-architecture-decisions.md` from `init.md` (no editor opened).

**Examples:**
```
adr init
adr init documentation/decisions
```

---

## `adr new [-s N] [-l TARGET:LINK:REVERSE-LINK] TITLE...`

Create a new Architecture Decision Record.

**Required:** `TITLE...` — the decision title (multiple words are concatenated; lowercased and slugified into the filename).

**Options (short forms only — no `--supersede`/`--link` long forms):**
- `-s N` — supersede the ADR identified by `N` (number or partial filename). Repeatable.
- `-l TARGET:LINK:REVERSE-LINK` — link to an existing ADR. `TARGET` = reference, `LINK` = label written into the new ADR, `REVERSE-LINK` = label written into the target ADR. Repeatable.

**What it does:**
1. Numbers the ADR (`NNNN`, zero-padded, max existing number + 1).
2. Creates `NNNN-slug.md` from the template with `Date` (ISO 8601) and `Status: Accepted`.
3. Opens it in `${VISUAL:-${EDITOR:-true}}` and prints the file path to stdout.
4. With `-s`, writes `Supercedes [title](file)` into the new ADR and `Superceded by [title](file)` into the target, removing `Accepted` from the target.

**Examples:**
```
adr new Use PostgreSQL for primary data store
adr new "Migrate to PostgreSQL" -s 3
adr new "Use Redis for caching" -l "5:Depends on:Enables"
```

---

## `adr link SOURCE LINK TARGET REVERSE-LINK`

Link two existing ADRs. All four arguments are required.

- `SOURCE` — reference (number or partial filename) of the source ADR.
- `LINK` — label written into SOURCE's Status section.
- `TARGET` — reference of the target ADR.
- `REVERSE-LINK` — label written into TARGET's Status section.

**Examples:**
```
adr link 12 Amends 10 "Amended by"
adr link 7 "Depends on" 3 "Required by"
```

---

## `adr list`

List all ADRs, sorted, one path per line. Errors with `The <dir> directory does not exist` if no ADR repo is present.

```
adr list
```

---

## `adr generate [REPORT [OPTION...]]`

Generate a report. With no `REPORT`, lists available generators (`toc`, `graph`).

### `adr generate toc [-i INTRO] [-o OUTRO] [-p LINK_PREFIX]`

Emit a markdown table of contents (`# Architecture Decision Records` + one `* [title](link)` per ADR) to stdout.
- `-i INTRO` — markdown file prepended to the TOC.
- `-o OUTRO` — markdown file appended to the TOC.
- `-p LINK_PREFIX` — prefix each link.

```
adr generate toc
```

### `adr generate graph [-p LINK_PREFIX] [-e LINK-EXTENSION]`

Emit a Graphviz `digraph` to stdout (pipe to `dot` to render). Nodes are ADRs; relationship edges come from each ADR's Status links (reverse links ending in "by" are dropped).
- `-p LINK_PREFIX` — prefix each node's URL.
- `-e LINK-EXTENSION` — link extension, defaults to `.html`.

```
adr generate graph | dot -Tsvg > graph.svg
```

---

## `adr config`

Print the shell config the CLI derives at runtime (`adr_bin_dir`, `adr_template_dir`). This is a bootstrap shim, not a settings manager — there is no user-editable config file.

---

## `adr upgrade-repository`

Upgrade existing ADR documents to the latest format (converts `Date: DD/MM/YYYY` to ISO 8601 `YYYY-MM-DD`).

```
adr upgrade-repository
```

---

## `adr help [COMMAND]`

Show usage. With `COMMAND`, show that command's help. Uses `ADR_PAGER`/`PAGER` (default `more`).

```
adr help
adr help new
```

---

## Environment Variables

| Variable | Effect |
|---|---|
| `ADR_TEMPLATE` | Template file used by `adr new` (else `templates/template.md` in the ADR dir, else the install dir's `template.md`) |
| `ADR_DATE` | Override the date written into a new ADR (default `date +%Y-%m-%d`) |
| `VISUAL` / `EDITOR` | Editor opened by `adr new` (default `true` = no edit) |
| `ADR_PAGER` / `PAGER` | Pager for `adr help` (default `more`) |

---

## ADR File Format

Generated from `template.md` (placeholders `NUMBER`, `TITLE`, `DATE`, `STATUS` → `Accepted` are substituted by `adr new`):

```markdown
# NUMBER. TITLE

Date: DATE

## Status

STATUS

## Context

The issue motivating this decision, and any context that influences or constrains the decision.

## Decision

The change that we're proposing or have agreed to implement.

## Consequences

What becomes easier or more difficult to do and any risks introduced by the change that will need to be mitigated.
```

---

## Directory Discovery

The CLI locates the ADR directory by walking up from the current directory:
1. `.adr-dir` file (written by `adr init <dir>`) — path resolved relative to the directory containing `.adr-dir`.
2. `doc/adr` directory.
3. Falls back to `doc/adr`.

---

## Status Values

Status is free-form text in the `## Status` section. Common values:
- **Accepted** — default set by `adr new`; current active decision.
- **Supercedes [title](file)** — written into a new ADR by `adr new -s`.
- **Superceded by [title](file)** — written into the superseded ADR (the tool spells "Superceded" with one "d").
- Relationship labels (`Amends`, `Amended by`, `Depends on`, `Required by`, `Relates to`, ...) via `adr link` / `adr new -l`.

---

## Linking ADRs

`adr link` and `adr new -l` write link lines into each ADR's Status section as `Label [title](file)`. Labels are free-form; conventional pairs:

| Forward | Reverse |
|---|---|
| Amends | Amended by |
| Depends on | Required by |
| Relates to | Related to |
| Supercedes | Superceded by (via `adr new -s`) |

---

## Error Messages

- **"The `<dir>` directory does not exist"** — run `adr init` first.
- **"ERROR: no title given"** — `adr new` requires a title.
- **"Not implemented: `-x`"** — unknown flag passed to `adr new`.
