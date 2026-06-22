---
name:   lnav
description: assisting human exploring logs with lnav tool
---

## Table of Contents

1. [Views](#views)
2. [Keyboard Shortcuts](#keyboard-shortcuts)
3. [Colon Commands](#colon-commands)
4. [Configuration](#configuration)
5. [SQL Integration](#sql-integration)
6. [Prompt Editing](#prompt-editing)
7. [Keymap Customization](#keymap-customization)
8. [Command-Line Flags](#command-line-flags)

---

## Views

| View         | Switch To           | Description                                  |
|--------------|---------------------|----------------------------------------------|
| LOG          | default on open     | Log file view with parsing/filtering         |
| TEXT         | `t`                 | Raw text file view                           |
| HELP         | `?` or `F1`         | Built-in help                                |
| HISTOGRAM    | `i`                 | Histogram of log message frequency           |
| SPECTROGRAM  | `:spectrogram` cmd  | Numeric field visualization                  |
| SQL/DB       | `v`                 | SQL query results                            |
| PRETTY       | `Shift+p`           | Pretty-printed view of logs/text             |
| SCHEMA       | `:switch-to-view schema` | Database schema browser               |
| TIMELINE     | `:switch-to-view timeline` | Timeline view                        |

`q` returns to previous view. `a` restores a popped view.

---

## Keyboard Shortcuts

### Global

| Key       | Action                                                        |
|-----------|---------------------------------------------------------------|
| `Ctrl+C`  | SIGINT to child process / quick exit (3x = abort)            |
| `Ctrl+R`  | Reset session state (clears filters, bookmarks, highlights)  |

### Spatial Navigation (all views)

| Key                         | Action                                     |
|-----------------------------|--------------------------------------------|
| `Space` / `PgDn`           | Down a page                                |
| `b` / `Backspace` / `PgUp` | Up a page                                  |
| `Ctrl+d`                    | Down half a page                           |
| `Ctrl+u`                    | Up half a page                             |
| `j` / `Down`                | Down a line                                |
| `k` / `Up`                  | Up a line                                  |
| `h` / `Left`                | Left half a page (reveals source file)     |
| `Shift+h` / `Shift+Left`   | Left 10 columns                            |
| `l` / `Right`               | Right half a page                          |
| `Shift+l` / `Shift+Right`  | Right 10 columns                           |
| `Home` / `g`                | Top of view                                |
| `End` / `G`                 | Bottom of view                             |

### Mark Navigation

| Key           | Action                                            |
|---------------|---------------------------------------------------|
| `e` / `E`     | Next / previous error                             |
| `w` / `W`     | Next / previous warning                           |
| `n` / `N`     | Next / previous search hit                        |
| `>` / `<`     | Next / previous search hit (horizontal scroll)    |
| `f` / `F`     | Next / previous file                              |
| `u` / `U`     | Next / previous user bookmark                     |
| `o` / `O`     | Forward/backward through matching opid messages   |
| `s` / `S`     | Next / previous log rate slowdown                 |
| `{` / `}`     | Previous / next section                           |
| `F7` / `F8`   | Previous / next breakpoint                        |
| `Ctrl+b`      | Toggle breakpoint on focused line                 |

### Chronological Navigation (time-based views)

| Key                | Action                                  |
|--------------------|-----------------------------------------|
| `d` / `D`          | Forward / backward 24 hours             |
| `1`-`6` / `!`-`^`  | Next / previous Nth 10-min of hour      |
| `7` / `8`          | Previous / next minute                  |
| `0` / `)`          | Next / previous day                     |
| `r` / `R`          | Forward / backward by last goto delta   |

### Bookmarks

| Key        | Action                                           |
|------------|--------------------------------------------------|
| `m`        | Toggle bookmark on top/cursor line               |
| `M`        | Bookmark range from last mark to top             |
| `J`        | Bookmark next line after last marked             |
| `K`        | Bookmark previous line                           |
| `c`        | Copy marked lines to clipboard                   |
| `C`        | Clear all marked lines                           |
| `Ctrl+s`   | Toggle sticky header on focused line             |

### Display Controls

| Key        | Action                                           |
|------------|--------------------------------------------------|
| `?` / `F1` | Toggle help view                                 |
| `q`        | Return to previous view / quit                   |
| `Q`        | Return to previous view, match top times         |
| `a` / `A`  | Restore popped view (A matches times)            |
| `P`        | Toggle pretty-printed view                       |
| `T`        | Show elapsed time from bookmark to line          |
| `t`        | Toggle text file view                            |
| `i` / `I`  | Toggle histogram view (I syncs time)             |
| `z` / `Z`  | Zoom in / out (HIST/SPECTRO views)               |
| `v` / `V`  | Toggle SQL result view (V jumps to log_line)     |
| `p`        | Toggle log parser result display                 |
| `Tab`      | Focus config panel (filters / files)             |
| `Ctrl+l`   | Lo-fi mode (raw text dump for copy)              |
| `Ctrl+w`   | Toggle word-wrap                                 |
| `Ctrl+p`   | Toggle data preview panel                        |
| `Ctrl+f`   | Toggle all filters on/off                        |
| `x`        | Toggle hidden log fields                         |
| `Ctrl+x`   | Toggle cursor mode                               |
| `=`        | Pause / unpause file loading                     |
| `X`        | Close current file                               |
| `F2`       | Toggle mouse support                             |

### Query Prompts

| Key    | Action                          |
|--------|---------------------------------|
| `/`    | Open regex search prompt        |
| `;`    | Open SQL prompt                 |
| `:`    | Open command prompt             |
| `\|`   | Open script prompt              |
| `Ctrl+]` | Abort prompt                  |

### Breadcrumb Navigation

| Key        | Action                                     |
|------------|--------------------------------------------|
| `` ` ``    | Focus breadcrumb bar                       |
| `Enter`    | Accept value, drop focus                   |
| `Escape`   | Drop focus                                 |
| `Left`     | Select crumb left                          |
| `Right`    | Accept value, move to next crumb           |
| `Ctrl+a`   | Select first crumb                         |
| `Ctrl+e`   | Select last crumb                          |
| `Up/Down`  | Navigate crumb dropdown values             |
| `Home/End` | First/last dropdown value                  |

---

## Colon Commands

Activate with `:` key. Most support TAB-completion. Preview activates before Enter.

### File Operations

| Command | Syntax | Description |
|---------|--------|-------------|
| `open` | `:open [--since TIME] [--until TIME] PATH` | Open file(s) locally or remote (`user@host:/path`) |
| `close` | `:close [PATH\|GLOB]` | Close file(s) |
| `xopen` | `:xopen PATH` | Open with external command |
| `hide-file` | `:hide-file [PATH\|GLOB]` | Hide file, skip indexing |
| `show-file` | `:show-file PATH\|GLOB` | Resume indexing hidden file |
| `show-only-this-file` | `:show-only-this-file` | Show only focused file |
| `add-source-path` | `:add-source-path PATH` | Index source for better parsing |
| `rebuild` | `:rebuild` | Force rebuild file indexes |

### Filtering

| Command | Syntax | Description |
|---------|--------|-------------|
| `filter-in` | `:filter-in REGEX` | Show only matching lines |
| `filter-out` | `:filter-out REGEX` | Hide matching lines |
| `filter-expr` | `:filter-expr SQL_EXPR` | Filter by SQL expression (e.g. `:log_level = 'error'`) |
| `clear-filter-expr` | `:clear-filter-expr` | Clear filter expression |
| `delete-filter` | `:delete-filter REGEX` | Delete a filter |
| `enable-filter` | `:enable-filter REGEX` | Re-enable disabled filter |
| `disable-filter` | `:disable-filter REGEX` | Disable a filter |
| `toggle-filtering` | `:toggle-filtering` | Toggle all filters on/off |
| `hide-lines-before` | `:hide-lines-before DATE` | Hide lines before timestamp |
| `hide-lines-after` | `:hide-lines-after DATE` | Hide lines after timestamp |
| `show-lines-before-and-after` | `:show-lines-before-and-after` | Restore hidden lines |
| `hide-unmarked-lines` | `:hide-unmarked-lines` | Hide non-bookmarked lines |
| `show-unmarked-lines` | `:show-unmarked-lines` | Show non-bookmarked lines |
| `set-min-log-level` | `:set-min-log-level LEVEL` | Set minimum log level (trace..fatal) |

### Navigation

| Command | Syntax | Description |
|---------|--------|-------------|
| `goto` | `:goto LINE\|N%\|TIMESTAMP\|#ANCHOR` | Go to location |
| `relative-goto` | `:relative-goto +N\|-N\|N%` | Move relative amount |
| `next-mark` | `:next-mark TYPE` | Go to next bookmark (error/warning/search/user/file/meta) |
| `prev-mark` | `:prev-mark TYPE` | Go to previous bookmark |
| `next-section` | `:next-section` | Next section/partition |
| `prev-section` | `:prev-section` | Previous section/partition |
| `next-location` | `:next-location` | Next in location history |
| `prev-location` | `:prev-location` | Previous in location history |
| `switch-to-view` | `:switch-to-view NAME` | Switch to named view |
| `toggle-view` | `:toggle-view NAME` | Toggle a view on/off |

### Annotations & Tags

| Command | Syntax | Description |
|---------|--------|-------------|
| `mark` | `:mark` | Toggle bookmark on focused line |
| `mark-expr` | `:mark-expr SQL_EXPR` | Bookmark lines matching expression |
| `clear-mark-expr` | `:clear-mark-expr` | Clear mark expression |
| `comment` | `:comment TEXT` | Attach comment (supports Markdown) |
| `clear-comment` | `:clear-comment` | Remove comment |
| `tag` | `:tag #TAG ...` | Attach tags to line |
| `untag` | `:untag #TAG ...` | Remove tags from line |
| `delete-tags` | `:delete-tags #TAG ...` | Remove tags from all lines |
| `partition-name` | `:partition-name NAME` | Mark start of partition |
| `clear-partition` | `:clear-partition` | Clear partition |
| `annotate` | `:annotate` | Auto-analyze focused line |

### Highlighting

| Command | Syntax | Description |
|---------|--------|-------------|
| `highlight` | `:highlight REGEX` | Color matching text fragments |
| `clear-highlight` | `:clear-highlight REGEX` | Remove highlight |
| `highlight-field` | `:highlight-field [--color=C] [--bold] [--underline] FIELD [REGEX]` | Highlight a field |
| `clear-highlight-field` | `:clear-highlight-field FIELD` | Remove field highlight |
| `hide-fields` | `:hide-fields FIELD` | Hide log field (ellipsis) |
| `show-fields` | `:show-fields FIELD` | Show hidden field |

### Time Manipulation

| Command | Syntax | Description |
|---------|--------|-------------|
| `adjust-log-time` | `:adjust-log-time TIMESTAMP` | Shift timestamps relative to given time |
| `clear-adjusted-log-time` | `:clear-adjusted-log-time` | Clear time adjustment |
| `convert-time-to` | `:convert-time-to ZONE` | Convert focused timestamp to timezone |
| `set-file-timezone` | `:set-file-timezone ZONE [GLOB]` | Set timezone for file(s) |
| `clear-file-timezone` | `:clear-file-timezone GLOB` | Clear file timezone |
| `current-time` | `:current-time` | Print current time |
| `unix-time` | `:unix-time SECONDS` | Convert epoch to readable time |

### SQL / Search Tables

| Command | Syntax | Description |
|---------|--------|-------------|
| `create-search-table` | `:create-search-table NAME [REGEX]` | Create regex search table |
| `create-logline-table` | `:create-logline-table NAME` | Create table from focused log line |
| `delete-search-table` | `:delete-search-table NAME` | Delete search table |
| `delete-logline-table` | `:delete-logline-table NAME` | Delete logline table |
| `summarize` | `:summarize COLUMN` | Analyze column characteristics |
| `spectrogram` | `:spectrogram FIELD` | Visualize numeric field |

### Output / Write

| Command | Syntax | Description |
|---------|--------|-------------|
| `write-to` | `:write-to [--anonymize] PATH` | Write marked lines |
| `write-csv-to` | `:write-csv-to [--anonymize] PATH` | Write SQL results as CSV |
| `write-json-to` | `:write-json-to [--anonymize] PATH` | Write SQL results as JSON |
| `write-json-cols-to` | `:write-json-cols-to [--anonymize] PATH` | Write JSON (flattened columns) |
| `write-jsonlines-to` | `:write-jsonlines-to [--all] [--anonymize] PATH` | Write as JSON Lines |
| `write-table-to` | `:write-table-to [--anonymize] PATH` | Write SQL results as text table |
| `write-raw-to` | `:write-raw-to [--view] [--anonymize] PATH` | Write original log content |
| `write-screen-to` | `:write-screen-to [--anonymize] PATH` | Write displayed text |
| `write-view-to` | `:write-view-to [--anonymize] PATH` | Write top view content |
| `write-debug-log-to` | `:write-debug-log-to PATH` | Write internal debug log |
| `append-to` | `:append-to PATH` | Append marked lines to file |
| `pipe-to` | `:pipe-to SHELL_CMD` | Pipe marked lines to shell cmd |
| `pipe-line-to` | `:pipe-line-to SHELL_CMD` | Pipe focused line to shell cmd |
| `redirect-to` | `:redirect-to [PATH]` | Redirect cmd output to file |

### Session

| Command | Syntax | Description |
|---------|--------|-------------|
| `save-session` | `:save-session` | Save current state |
| `load-session` | `:load-session` | Load latest session |
| `reset-session` | `:reset-session` | Clear all session state |
| `export-session-to` | `:export-session-to PATH` | Export as executable script |
| `session` | `:session CMD` | Add command to session file |

### Display

| Command | Syntax | Description |
|---------|--------|-------------|
| `enable-word-wrap` | `:enable-word-wrap` | Enable word wrap |
| `disable-word-wrap` | `:disable-word-wrap` | Disable word wrap |
| `set-text-view-mode` | `:set-text-view-mode MODE` | Set text display mode |
| `zoom-to` | `:zoom-to LEVEL` | Set histogram zoom (e.g. `1-week`) |
| `redraw` | `:redraw` | Full screen redraw |

### System

| Command | Syntax | Description |
|---------|--------|-------------|
| `config` | `:config OPTION [VALUE]` | Read/write config option |
| `reset-config` | `:reset-config OPTION` | Reset config to default |
| `sh` | `:sh --name=NAME CMD` | Execute shell command, capture output |
| `cd` | `:cd DIR` | Change directory |
| `eval` | `:eval CMD` | Execute with variable substitution |
| `echo` | `:echo [-n] MSG` | Display message |
| `alt-msg` | `:alt-msg MSG` | Display message in alt position |
| `help` | `:help` | Open help view |
| `quit` | `:quit` | Quit lnav |
| `prompt` | `:prompt TYPE [--alt] [PROMPT] [INIT]` | Open prompt |
| `external-access` | `:external-access PORT API_KEY` | Open remote access port |
| `external-access-login` | `:external-access-login [APP]` | Open external access URL |
| `breakpoint` | `:breakpoint [FMT:]FILE:LINE` | Set breakpoint |
| `clear-breakpoint` | `:clear-breakpoint GLOB` | Clear breakpoints |
| `enable-breakpoint` | `:enable-breakpoint POINT` | Enable breakpoint |
| `disable-breakpoint` | `:disable-breakpoint POINT` | Disable breakpoint |
| `toggle-breakpoint` | `:toggle-breakpoint` | Toggle breakpoint on focused line |
| `toggle-sticky-header` | `:toggle-sticky-header` | Toggle sticky header |
| `clear-all-sticky-headers` | `:clear-all-sticky-headers` | Clear all sticky headers |
| `hide-in-timeline` | `:hide-in-timeline TYPE...` | Hide timeline row types |
| `show-in-timeline` | `:show-in-timeline TYPE...` | Show timeline row types |

### LNAVSECURE Restrictions

When `LNAVSECURE` env var is set, these commands are disabled:
`:cd`, `:export-session-to`, `:open`, `:pipe-to`, `:pipe-line-to`, `:redirect-to`, `:sh`, `:write-*-to`

---

## Configuration

### Config File Locations (load order, later overrides earlier)

1. Built-in defaults
2. `/etc/lnav/configs/*/*.json`
3. `~/.lnav/configs/default/*.json`
4. `~/.lnav/configs/*/*.json`
5. `-I <path>/configs/*/*.json`
6. `~/.lnav/config.json` (local overrides)

All config files use JSON with schema: `https://lnav.org/schemas/config-v1.schema.json`

### UI Settings (`/ui/...`)

| Path | Type | Default | Description |
|------|------|---------|-------------|
| `/ui/clock-format` | string | `"%Y-%m-%dT%H:%M:%S %Z"` | Clock format (strftime) |
| `/ui/dim-text` | bool | `false` | Reduce text brightness (xterm) |
| `/ui/default-colors` | bool | `true` | Use terminal default bg/fg colors |
| `/ui/keymap` | string | `"default"` | Active keymap name |
| `/ui/theme` | string | `"default"` | Active theme name |
| `/ui/mouse/mode` | enum | `"enabled"` | Mouse: `enabled` / `disabled` |
| `/ui/movement/mode` | enum | `"cursor"` | Movement: `top` / `cursor` |
| `/ui/views/log/time-column` | enum | `"disabled"` | Time column: `disabled` / `enabled` / `default` |

### Log Settings (`/log/...`)

| Path | Type | Default | Description |
|------|------|---------|-------------|
| `/log/date-time/convert-zoned-to-local` | bool | `true` | Convert zoned timestamps to local |

### Watch Expressions (`/log/watch-expressions/<name>/`)

| Field | Type | Description |
|-------|------|-------------|
| `expr` | string | SQL expression evaluated per line |
| `enabled` | bool | Whether active |

### Annotations (`/log/annotations/<name>/`)

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Description |
| `condition` | string | SQL expression to match log messages |
| `handler` | string | Script to generate annotation content |

### Tuning (`/tuning/...`)

| Path | Type | Default | Description |
|------|------|---------|-------------|
| `/tuning/archive-manager/min-free-space` | int | `33554432` | Min free space for archives (bytes) |
| `/tuning/archive-manager/cache-ttl` | duration | `"2d"` | Archive cache TTL |
| `/tuning/piper/max-size` | int | `10485760` | Max capture file size |
| `/tuning/piper/rotations` | int | `4` | Rotated files to keep |
| `/tuning/piper/ttl` | duration | `"2d"` | Captured data TTL |
| `/tuning/textfile/max-unformatted-line-length` | int | `2048` | Auto-format threshold |
| `/tuning/remote/ssh/command` | string | `"ssh"` | SSH binary |
| `/tuning/remote/ssh/config/BatchMode` | string | `"yes"` | SSH config |
| `/tuning/remote/ssh/config/ConnectTimeout` | string | `"10"` | SSH timeout |

### Theme Definition (`/ui/theme-defs/<name>/`)

Styles are objects with optional: `color`, `background-color`, `bold`, `italic`, `underline`, `strike`, `text-align`.

**Log level styles** (`/ui/theme-defs/<name>/log-level-styles/`):
`trace`, `debug5`, `debug4`, `debug3`, `debug2`, `debug`, `info`, `stats`, `notice`, `warning`, `error`, `critical`, `fatal`, `invalid`

**UI styles** (`/ui/theme-defs/<name>/styles/`):
`text`, `alt-text`, `selected-text`, `error`, `ok`, `info`, `warning`, `hidden`, `cursor-line`, `disabled-cursor-line`, `adjusted-time`, `skewed-time`, `file-offset`, `offset-time`, `time-column`, `invalid-msg`, `popup`, `popup-border`, `focused`, `disabled-focused`, `scrollbar`, `h1`-`h6`, `hr`, `hyperlink`, `breadcrumb`, `table-border`, `table-header`, `snippet-border`, `indent-guide`, `timeline-bar`, etc.

**Syntax styles** (`/ui/theme-defs/<name>/syntax-styles/`):
`keyword`, `string`, `comment`, `variable`, `symbol`, `null`, `number`, `type`, `function`, `file`, `inline-code`, `quoted-code`, `object-key`, `diff-delete`, `diff-add`, `re-special`, `re-repeat`, etc.

---

## SQL Integration

Open SQL prompt with `;`. Uses embedded SQLite with virtual tables.

### Key Virtual Tables

| Table | Description |
|-------|-------------|
| `all_logs` | All loaded log messages |
| `lnav_file` | File metadata and content |
| `lnav_views` | View state (selection, top, paused) |
| `lnav_top_view` | Current top view properties |
| `lnav_view_stack` | View navigation stack |
| `hop_table` | Key-value store for scripts |
| `<format_name>` | Per-format tables (e.g. `access_log`, `syslog_log`) |

### Log Column Access (in SQL expressions)

Prefix column names with `:` in `:filter-expr` and `:mark-expr`:
- `:log_level` — log level
- `:log_body` — message body
- `:log_procname` — process name
- `:log_format` — format name
- `:log_time` — timestamp
- `:log_line` — line number

### Useful SQL Examples

```sql
-- Count messages by level
SELECT log_level, count(*) FROM all_logs GROUP BY log_level ORDER BY count(*) DESC;

-- Find errors in last hour
SELECT * FROM all_logs WHERE log_level = 'error' AND log_time > datetime('now', '-1 hour');

-- Top IP addresses from access logs
SELECT sc_ip, count(*) as cnt FROM access_log GROUP BY sc_ip ORDER BY cnt DESC LIMIT 20;

-- Move log view to a specific line
UPDATE lnav_views SET selection = 42 WHERE name = 'log';

-- Toggle cursor mode
UPDATE lnav_top_view SET movement = CASE movement WHEN 'top' THEN 'cursor' ELSE 'top' END;
```

### Built-in SQLite Functions

- `log_msg_line()` — current focused line number
- `log_msg_format()` — current log format name
- `log_msg_text()` — current message text
- `log_msg_path()` — current file path
- `jget(json, pointer, default)` — JSON pointer extraction

---

## Prompt Editing

| Key | Action |
|-----|--------|
| `Escape` | Close popup / exit search / cancel prompt |
| `Enter` | Execute (single-line) or newline (multi-line) |
| `Ctrl+X` | Execute and close prompt |
| `F1` | Open help for prompt |
| `Ctrl+A` | Beginning of line |
| `Ctrl+E` | End of line |
| `Ctrl+K` | Cut to end of line |
| `Ctrl+U` | Cut from start to cursor |
| `Ctrl+W` | Cut previous word |
| `Ctrl+Y` | Paste clipboard |
| `Ctrl+_` | Undo |
| `Tab` / `Enter` | Accept completion |
| `Ctrl+L` | Reformat SQL + switch to multi-line |
| `Ctrl+O` | Save as script + open in editor |
| `Ctrl+S` | Search mode (multi-line) |
| `Ctrl+R` | Search history / previous occurrence |

---

## Keymap Customization

Keys are specified as hex-encoded UTF-8 bytes prefixed with `x`. Examples:

| Hex | Key |
|-----|-----|
| `x3a` | `:` |
| `x2f` | `/` |
| `x3b` | `;` |
| `x7c` | `\|` |
| `x3f` | `?` |
| `x0c` | `Ctrl+L` |
| `x04` | `Ctrl+D` |
| `x15` | `Ctrl+U` |
| `x13` | `Ctrl+S` |
| `x06` | `Ctrl+F` |
| `x17` | `Ctrl+W` |
| `x18` | `Ctrl+X` |
| `f1`-`f12` | Function keys |

### Bind a Key via `:config`

```
:config /ui/keymap-defs/default/f9/command ;SELECT log_line FROM all_logs WHERE log_line > log_msg_line() AND log_body LIKE '%Starting%' LIMIT 1
```

### Keymap Definition Structure (in config JSON)

```json
{
  "/ui/keymap-defs": {
    "default": {
      "x3f": {
        "command": ":toggle-view help"
      },
      "f9": {
        "command": ";UPDATE lnav_views SET selection = ...",
        "alt-msg": "Custom help message",
        "id": "org.example.my-key"
      }
    }
  }
}
```

Command values must start with `:` (command), `;` (SQL), or `|` (script).

---

## Command-Line Flags

| Flag | Description |
|------|-------------|
| `-d` | Write debug log to `~/.lnav/lnav.debug` |
| `-f PATH` | Execute lnav script file |
| `-I PATH` | Additional config/format directory |
| `-n` | Run without curses (headless mode) |
| `-N` | No stdin |
| `-r` | Rotate terminal colors for differentiation |
| `-t` | Prepend timestamps to stdin lines |
| `-u` | Update formats from git |
| `-w` | Write stdin to file for later viewing |
| `-W` | Write mode: `overwrite` / `append` |

---

## Built-in Log Formats

- Syslog (and variants: vpp, vmacore, etc.)
- Apache access/error logs
- Nginx access/error logs
- Strace output
- tcsh history
- Generic timestamped logs
- JSON-lines
- logfmt
- Bro TSV / W3C Extended Log
- PostgreSQL / vPostgreSQL logs
- CUPS page_log
- vmware hostd/vpxa logs
- And many more (auto-detected by content)

---

## Quick Workflow Patterns

### Investigate errors in a log file
```
lnav /var/log/syslog
e           # jump to first error
v           # inspect in SQL view
;SELECT * FROM all_logs WHERE log_level = 'error'
```

### Filter and export
```
:filter-in dhclient        # show only dhclient messages
m                          # mark interesting lines
:write-to /tmp/out.txt     # export marked lines
```

### Remote log analysis
```
:open user@host:/var/log/syslog
:filter-expr :log_level COLLATE loglevel >= 'warning'
```

### Search and navigate
```
/error.*timeout            # search for error timeout
n                          # next match
c                          # copy marked lines to clipboard
```

### SQL-based analysis
```
;SELECT log_time, log_body FROM all_logs WHERE log_body LIKE '%connection%' ORDER BY log_time
:write-csv-to /tmp/conn-events.csv
```
