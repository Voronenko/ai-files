---
name:  lnav-unattended
description: use lnav tool when user asks you to filter logs
---

## Key CLI Flags

| Flag | Purpose |
|------|---------|
| `-n` | Headless mode — no curses UI |
| `-c CMD` | Execute a single command after files load (repeatable) |
| `-f FILE` | Execute commands from a `.lnav` script file |
| `-e CMD` | Execute a shell command and capture output |
| `-q` | Quiet — suppress default log output after commands finish |
| `-t` | Prepend timestamps to stdin lines |
| `-d FILE` | Write debug log to file |
| `-r` | Recursively load files from directories |
| `-R` | Load rotated log files |
| `-N` | Do not open default syslog |

---

## Core Pattern

```
lnav -n [-q] -c "CMD1" -c "CMD2" ... -c "OUTPUT_CMD"  LOGFILE [LOGFILE ...]
```

- `-n` disables the TUI
- Each `-c` is executed in order after file loading
- Commands starting with `:` are lnav commands
- Commands starting with `;` are SQL statements
- Pass `-` as the output path to write to **stdout**

---

## Output Targets (the `-` means stdout)

| Command | Format | Writes |
|---------|--------|--------|
| `:write-csv-to -` | CSV | Last SQL result as comma-separated |
| `:write-table-to -` | Aligned text | Last SQL result as text table |
| `:write-json-to -` | JSON array | Last SQL result as JSON |
| `:write-jsonlines-to -` | JSON Lines | One JSON object per row |
| `:write-json-cols-to -` | Columnar JSON | Flattened JSON columns |
| `:write-raw-to -` | Raw text | Original log file content of marked lines |
| `:write-view-to -` | Plain text | Top view content (formatted) |
| `:write-screen-to -` | Plain text | Displayed text |
| `:write-to -` | Plain text | Marked lines in current view |
| `:echo MSG` | Text | Plain message to stdout |

---

## Examples

### 1. Extract errors to CSV file

```bash
lnav -n \
    -c ";SELECT log_time, log_level, log_body FROM all_logs WHERE log_level = 'error'" \
    -c ":write-csv-to /tmp/errors.csv" \
    /var/log/syslog
```

### 2. Filter by regex, write raw to file

```bash
lnav -n \
    -c ":filter-in connection refused" \
    -c ":mark-expr :log_body REGEXP 'connection refused'" \
    -c ":hide-unmarked-lines" \
    -c ":write-raw-to /tmp/conn-refused.log" \
    /var/log/syslog
```

### 3. Extract top IPs from access log to stdout (pipe-friendly)

```bash
lnav -n \
    -c ";SELECT c_ip, count(*) AS hits FROM access_log GROUP BY c_ip ORDER BY hits DESC LIMIT 20" \
    -c ":write-csv-to -" \
    access.log
```

### 4. Filter by time range, output JSON

```bash
lnav -n \
    -c ":goto 2025-04-16T06:00:00" \
    -c ":hide-lines-before here" \
    -c ":goto 2025-04-16T18:00:00" \
    -c ":hide-lines-after here" \
    -c ";SELECT log_time, log_body FROM all_logs" \
    -c ":write-json-to /tmp/daytime-logs.json" \
    /var/log/syslog
```

### 5. Combine filter-in + SQL to file

```bash
lnav -n \
    -c ":filter-in sshd" \
    -c ";SELECT log_time, log_body FROM all_logs WHERE log_body LIKE '%sshd%'" \
    -c ":write-csv-to -" \
    /var/log/auth.log
```

### 6. Pipe lnav output to another tool

```bash
lnav -n -q \
    -c ";SELECT log_time, log_body FROM all_logs WHERE log_level >= 'warning'" \
    -c ":write-csv-to -" \
    /var/log/syslog | grep -i timeout
```

### 7. Process stdin with timestamps, filter, output

```bash
journalctl -u nginx --since "1 hour ago" | lnav -n -t \
    -c ":filter-in error" \
    -c ";SELECT log_time, log_body FROM all_logs" \
    -c ":write-csv-to -"
```

### 8. Anonymize and export

```bash
lnav -n \
    -c ";SELECT * FROM access_log" \
    -c ":write-csv-to --anonymize /tmp/anonymized.csv" \
    access.log
```

### 9. Run shell command and capture output in lnav

```bash
lnav -n -e "journalctl -u docker --since '1 hour ago'" \
    -c ":filter-in error" \
    -c ";SELECT log_time, log_body FROM all_logs" \
    -c ":write-csv-to -"
```

### 10. Extract field values using search tables

```bash
lnav -n \
    -c ":create-search-table durations duration=(?<dur>\\d+)ms" \
    -c ";SELECT dur, count(*) FROM durations GROUP BY dur ORDER BY count(*) DESC LIMIT 10" \
    -c ":write-csv-to -" \
    app.log
```

### 11. Summarize a column

```bash
lnav -n \
    -c ";SELECT * FROM access_log LIMIT 0" \
    -c ":summarize sc_bytes" \
    -c ":write-table-to -" \
    access.log
```

### 12. Remote log analysis — filter and download

```bash
lnav -n \
    -c ";SELECT log_time, log_level, log_body FROM all_logs WHERE log_level = 'error'" \
    -c ":write-csv-to /tmp/remote-errors.csv" \
    user@host:/var/log/syslog
```

### 13. Multi-step session: filter, mark, export

```bash
lnav -n \
    -c ":filter-in kernel" \
    -c ":filter-out USB" \
    -c ":mark-expr :log_body LIKE '%OOM%'" \
    -c ":hide-unmarked-lines" \
    -c ":write-raw-to /tmp/oom-events.log" \
    /var/log/kern.log
```

---

## Script Files (`.lnav`)

When the pipeline is complex, use a script file with `-f`.

### Script Syntax

```lnav
# Lines starting with # are comments
# @synopsis: my-script [args]
# @description: What this script does

# SQL queries (results stored for subsequent output commands)
;SELECT log_time, log_body FROM all_logs WHERE log_level = 'error'

# Write last SQL result to stdout
:write-csv-to -

# Or redirect all output to a file
:redirect-to /tmp/report.txt
:echo Error Report
:echo ============
;SELECT count(*) as total_errors FROM all_logs WHERE log_level = 'error'
:write-table-to -
:redirect-to
```

### Script Variables

| Variable | Description |
|----------|-------------|
| `$0` | Script path |
| `$1` ... `$N` | Positional arguments |
| `$__all__` | All arguments joined by space |
| `$LNAV_HOME_DIR` | lnav config directory |
| `$LNAV_WORK_DIR` | lnav cache directory |
| `$ENV_VAR` | Any environment variable |
| `$column_name` | Value from last SQL query single-row result |

### Execute a script

```bash
lnav -n -f my-script.lnav /var/log/syslog
lnav -n -f my-script.lnav -- /var/log/syslog   # same, explicit end of lnav opts
```

With arguments:

```bash
lnav -n -f report.lnav /var/log/nginx/access.log -- /tmp/output.txt
```

Inside script, `$1` = `/tmp/output.txt`.

### Real example from lnav source (`example-scripts/report-demo.lnav`)

```lnav
#
# @synopsis: report-demo [<output-path>]
# @description: Generate a report for requests in access_log files
#

;SELECT CASE WHEN $1 IS NULL THEN '-' ELSE $1 END AS out_path

:redirect-to $out_path

;SELECT printf('\n%d total requests', count(1)) AS msg FROM access_log
:echo $msg

;SELECT cs_uri_stem, count(1) AS total_hits
  FROM access_log
  WHERE sc_status BETWEEN 200 AND 300
  GROUP BY cs_uri_stem
  ORDER BY total_hits DESC
  LIMIT 50

:write-table-to -

:redirect-to
```

---

## Pattern: Filter → Export (the reliable recipe)

The most common unattended task: apply filters, write matching lines to a file.

### Via `:filter-in` / `:filter-out` + `:write-view-to`

```bash
lnav -n \
    -c ":filter-in dhclient" \
    -c ":filter-out DHCPREQUEST" \
    -c ":write-view-to /tmp/filtered.log" \
    /var/log/syslog
```

### Via SQL `SELECT` + `:write-csv-to`

```bash
lnav -n \
    -c ";SELECT log_time, log_body FROM all_logs WHERE log_body LIKE '%dhclient%' AND log_body NOT LIKE '%DHCPREQUEST%'" \
    -c ":write-csv-to /tmp/filtered.csv" \
    /var/log/syslog
```

### Via mark + `:write-raw-to` (original content, no formatting)

```bash
lnav -n \
    -c ":mark-expr :log_body LIKE '%timeout%'" \
    -c ":write-raw-to /tmp/timeouts.log" \
    /var/log/syslog
```

### Via mark + `:hide-unmarked-lines` + `:write-view-to`

```bash
lnav -n \
    -c ":mark-expr :log_level = 'error'" \
    -c ":hide-unmarked-lines" \
    -c ":write-view-to /tmp/errors.log" \
    /var/log/syslog
```

---

## Output Format Quick Reference

| You want... | Command |
|-------------|---------|
| CSV for spreadsheet/analysis | `:write-csv-to PATH` |
| JSON for programmatic consumption | `:write-json-to PATH` |
| JSON Lines for streaming/line-processing | `:write-jsonlines-to PATH` |
| Human-readable text table | `:write-table-to PATH` |
| Raw original log lines | `:write-raw-to PATH` |
| Formatted view as seen on screen | `:write-view-to PATH` |
| Marked lines only | `:mark` / `:mark-expr` then `:write-to PATH` |
| All log lines (no SQL) | `:write-view-to PATH` |
| To stdout (pipe to another tool) | Pass `-` as the PATH |
| Anonymized output (no PII) | Add `--anonymize` flag |

---

## Debugging Headless Runs

```bash
# Write debug log if something goes wrong
lnav -n -d /tmp/lnav-debug.log \
    -c ";SELECT * FROM all_logs LIMIT 5" \
    -c ":write-csv-to -" \
    /var/log/syslog

# Check config without processing
lnav -C /var/log/syslog

# Verify format detection
lnav -n -c ";SELECT filepath, format FROM lnav_file" -c ":write-csv-to -" /var/log/syslog
```
