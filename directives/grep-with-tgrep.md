# tgrep — Fast Indexed Repository Search

## Purpose

Use `tgrep` instead of `grep`/`ripgrep` when repeatedly searching a large repository, especially monorepos with tens or hundreds of thousands of files.

`tgrep` builds a persistent trigram index and then uses that index to identify candidate files before running the full regex matcher. A long-running server keeps the index synchronized with filesystem changes.

Typical workflow:

```bash
tgrep index .
tgrep serve .
tgrep "pattern" .
```

Once the server is running, normal searches automatically connect to it.

## When to use tgrep

Prefer `tgrep` when:

- the repository is large (roughly 10k+ files, especially 100k+)
- many searches will be performed against the same repository
- an agent is repeatedly exploring the same codebase
- repository searches are becoming a latency bottleneck
- a persistent background process is acceptable

Prefer `rg`/`ripgrep` when:

- searching a small repository
- performing only one or two searches
- searching a single known file
- exact filesystem state is more important than indexed state
- using features that intentionally bypass the index

`tgrep` is designed as a drop-in-ish replacement for common ripgrep workflows.

## Core commands

### Build an index

```bash
tgrep index .
tgrep index /path/to/repo
tgrep index . --index-path /tmp/idx
```

Useful exclusions:

```bash
tgrep index . --exclude vendor --exclude third_party
```

For a directory containing `.gitignore` but not actually being a Git repository:

```bash
tgrep index . --no-require-git
```

### Start the server

```bash
tgrep serve .
```

The server:

- automatically builds the index if missing
- watches filesystem changes
- serves queries while indexing
- supports multiple clients
- maintains an in-memory overlay for changes
- periodically flushes the overlay to disk
- periodically reconciles against the filesystem to detect missed events

Useful options:

```bash
tgrep serve . --index-path /tmp/idx
tgrep serve . --no-watch
tgrep serve . --exclude node_modules
```

### Search

```bash
tgrep "fn main" .
tgrep "TODO|FIXME" .
tgrep "error" . -i
tgrep "error" . -S
tgrep -F "Vec<T>" .
```

Common examples:

```bash
tgrep "MyStruct" . -l
tgrep "pattern" . -c
tgrep "pattern" . -o
tgrep "pattern" . -w
tgrep "pattern" . -m 5
tgrep "pattern" . -g "*.rs"
tgrep "pattern" . -g "*.rs" -g "*.toml"
tgrep "pattern" . -t rust
tgrep "pattern" . -e "also_this"
tgrep "pattern" . -A 3 -B 2
```

Machine/editor output:

```bash
tgrep "pattern" . --json
tgrep "pattern" . --vimgrep
```

Debug query performance:

```bash
tgrep "pattern" . --stats
```

Force brute-force searching:

```bash
tgrep "pattern" . --no-index
```

## Important search flags

| Flag | Meaning |
|---|---|
| `-i` | case-insensitive |
| `-s` | case-sensitive |
| `-S` | smart-case |
| `-F` | fixed/literal string |
| `-w` | whole word |
| `-v` | invert match |
| `-o` | only matching text |
| `-e PATTERN` | additional OR pattern |
| `-f FILE` | read patterns from file |
| `-U` | multiline |
| `-n` | line numbers |
| `-N` | no line numbers |
| `-l` | filenames with matches |
| `--files-without-match` | filenames without matches |
| `-c` | count matches per file |
| `-q` | quiet / exit code only |
| `-m N` | maximum matching lines per file |
| `-g GLOB` | glob filter |
| `-t TYPE` | file type filter |
| `-T TYPE` | exclude file type |
| `-A N` | context after |
| `-B N` | context before |
| `-C N` | context before and after |
| `--json` | ripgrep-compatible JSON |
| `--vimgrep` | Vim-compatible output |
| `--stats` | query-plan/statistics output |
| `--no-index` | bypass index |

## File selection

By default, the index contains searchable text files while respecting repository ignore rules.

Useful commands:

```bash
tgrep --files .
tgrep --files src/main.rs
tgrep --files -t rust .
tgrep --type-list
tgrep count-files .
```

Useful traversal controls:

```bash
--hidden
--no-ignore
--no-ignore-vcs
--no-ignore-global
--no-require-git
--exclude DIR
--max-filesize SIZE
--no-max-filesize
--follow
--max-depth N
--one-file-system
```

## Critical index consistency rule

Options determining repository membership must be kept consistent between `index` and `serve`.

In particular:

- `--no-require-git`
- `--no-ignore`
- `--max-filesize`
- `--exclude`

For example:

```bash
tgrep index . --max-filesize 8M
tgrep serve . --max-filesize 8M
```

Do not build an index with one file-selection policy and serve it with another.

## File-size limit

`tgrep` defaults to a **64 MiB maximum searchable/indexed file size**.

This differs from ripgrep.

If large files must be searched:

```bash
tgrep index . --no-max-filesize
tgrep serve . --no-max-filesize
```

A file exceeding the default limit may be counted during traversal but won't be represented in the searchable index.

A directly named file is searched directly rather than relying on the inherited index behavior:

```bash
tgrep "needle" ./huge.log
```

## Index architecture

`tgrep` uses a hybrid indexed architecture:

```text
tgrep client
    |
   TCP
    |
tgrep serve
    |
    +-- HybridIndex
         |
         +-- IndexReader
         |    mmap'd persistent index
         |
         +-- LiveIndex
              in-memory changes
```

### IndexReader

The persistent index is memory-mapped and contains:

- sorted trigram lookup entries
- posting lists of matching file IDs
- file ID → path mappings
- filename-only sidecar data
- metadata

### LiveIndex

Tracks files changed after server startup or files currently being indexed.

The live layer takes precedence over the persistent layer.

### HybridIndex

Merges the persistent and live layers so searches see current content without requiring every mutation to immediately rewrite the disk index.

### File watcher

Filesystem notifications update the live index.

`tgrep` also periodically reconciles the index with the filesystem because filesystem notification systems can miss changes due to:

- event queue overflow
- virtual/network filesystems
- branch switches
- large directory replacements
- other watcher limitations

## Query algorithm

For a regex containing searchable literal fragments:

1. Parse the regex.
2. Extract literal fragments.
3. Convert fragments into trigrams.
4. Look up trigram posting lists using binary search.
5. Intersect/union posting lists to obtain candidate files.
6. Search only candidate files with the full regex engine.
7. Search candidates in parallel with rayon.

Therefore the expensive full-file scan is replaced by:

```text
query
  ↓
trigram lookup
  ↓
small candidate set
  ↓
parallel verification
```

This is why repeated searches can be dramatically faster than scanning the entire repository.

## Performance expectations

`tgrep` is optimized for repeated searches on large repositories.

Reported benchmark examples include:

- Gecko, 388k files, macOS arm64: ~52× faster than ripgrep
- Linux kernel, 96k files, Windows: ~35× faster
- Linux kernel, 96k files, macOS arm64: ~21× faster
- Chromium, 504k files, Windows: ~18× faster

The advantage depends strongly on:

- repository size
- query selectivity
- number of matching files
- platform
- amount of output

Queries returning tens of thousands of matches can reduce the relative advantage because output delivery becomes the dominant cost.

Do not assume every individual search will be faster than ripgrep.

## Indexing memory behavior

Full index builds default to:

```text
--index-strategy=external
```

The external strategy bounds memory by spilling sorted posting segments to disk and performing an external merge.

The alternative is:

```bash
tgrep index . --index-strategy=memory
```

which keeps the complete indexing structures in memory.

Use the external strategy for large repositories.

Memory can be further constrained with:

```bash
tgrep index . --index-buffer 16
```

The default index buffer is larger and generally provides a good performance/memory balance.

## Server resource controls

Important options:

```text
--max-memory <MB>
--max-cpu <PERCENT>
--auto-save-mutations <N>
--watcher-queue-cap <N>
```

Defaults include approximately:

- `--max-memory`: 50% of RAM, bounded between 512 MB and 16 GB
- `--max-cpu`: 50%
- `--auto-save-mutations`: 5000
- `--watcher-queue-cap`: 16384

Raise the watcher queue cap if logs indicate watcher queue overflows during bulk filesystem changes.

## Git and ignore behavior

`tgrep` follows repository ignore behavior similar to ripgrep.

A `.gitignore` outside a Git repository is not normally applied.

Use:

```bash
tgrep index . --no-require-git
```

and the same option when serving:

```bash
tgrep serve . --no-require-git
```

On case-insensitive Git filesystems, `tgrep` considers Git's `core.ignorecase` behavior when evaluating repository ignore rules.

Tracked files remain exempt from ignore rules in accordance with Git semantics.

## Important index bypass cases

Some options deliberately bypass the index because they alter the searchable file universe or interpretation.

Examples include:

```text
-E / --encoding
-a / --text
--binary
--hidden
--no-ignore*
```

Searching a single explicitly named file also normally bypasses the index because direct reading is cheaper.

If exact current filesystem contents are required:

```bash
tgrep "pattern" . --no-index
```

## Encoding behavior

`tgrep` automatically recognizes UTF-8/UTF-16 BOMs.

Explicit encoding:

```bash
tgrep "pattern" . -E utf-16le
```

Explicit encoding selection bypasses the index.

`tgrep` decodes text before indexing. Invalid UTF-8 bytes are repaired using U+FFFD. Positions are mapped back to disk byte offsets for normal output, but behavior differs from ripgrep for patterns that can match the replacement character.

## Binary files

Files containing NUL bytes are treated as binary.

During directory traversal, binary files are normally skipped.

Useful overrides:

```bash
tgrep "pattern" . -a
tgrep "pattern" . --binary
```

`tgrep` also rejects many known binary extensions during traversal to reduce indexing cost.

`-a` and `--binary` can lift that restriction.

## Multiline searches

Use:

```bash
tgrep "pattern" . -U
```

or:

```bash
tgrep "pattern" . --multiline-dotall
```

`tgrep` reports actual match positions for multiline matches rather than inheriting some of ripgrep's column-reporting quirks.

## Regex engine

Normal searches use the default regex engine.

For advanced constructs:

```bash
tgrep '\w+(?!_test)' .
```

or explicitly:

```bash
tgrep '\w+(?!_test)' . --pcre2
```

Engine selection:

```bash
--engine auto
--engine default
--engine pcre2
```

## Exit codes

`tgrep` follows ripgrep-style exit codes:

```text
0  match found
1  no match
2  error
```

A match plus an error normally returns `2`.

With `-q`, a match returns `0`.

## Status

Check the server:

```bash
tgrep status .
```

Typical information:

```text
PID
Port
Files
Trigrams
Cache
Watcher
Indexing
```

Use this when diagnosing whether the repository is indexed and whether the watcher is active.

## Recommended agent workflow

For a large repository:

### First use

```bash
tgrep serve .
```

If no index exists, the server will build one.

### Subsequent searches

Use normal commands:

```bash
tgrep "SomeSymbol" .
tgrep "SomeSymbol" src/
tgrep "TODO|FIXME" .
```

The client automatically connects to the running server.

### Inspecting performance

```bash
tgrep "SomeSymbol" . --stats
```

### Exact filesystem search

If index freshness or index membership is suspect:

```bash
tgrep "SomeSymbol" . --no-index
```

### Check server state

```bash
tgrep status .
```
