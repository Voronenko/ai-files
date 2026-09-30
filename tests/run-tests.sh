#!/usr/bin/env bash
# Validation matrix for the new ai-files-mcp / ai-files-setup behavior.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP="$REPO_ROOT/bin/ai-files-mcp"
SETUP="$REPO_ROOT/bin/ai-files-setup"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

# expect "<desc>" <command args...>  — command must exit 0
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}
# expect_fail "<desc>" <command args...>
expect_fail() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}
jqc() { jq -e "$2" "$1" >/dev/null 2>&1; }   # helper: file query

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-mcp-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

fresh() { # fresh <dir>
    rm -rf "${BASE:?}/$1"
    mkdir -p "$BASE/$1"
    git -C "$BASE/$1" init -q
}

echo "=== T1: fresh repo, built-in add writes all three configs ==="
T=$BASE/t1; fresh t1
(cd "$T" && "$MCP" add repo-memory -y) >/dev/null 2>&1
# Sentinels: jq-1.6 exits 0 on EMPTY input even with -e, so a truncated config
# would make every content check vacuously green. Parse-check first.
expect "t1 .mcp.json is valid JSON"     bash -c "jq -e . '$T/.mcp.json'      >/dev/null 2>&1"
expect "t1 opencode.json is valid JSON" bash -c "jq -e . '$T/opencode.json'  >/dev/null 2>&1"
expect "t1 zcode.json is valid JSON"    bash -c "jq -e . '$T/zcode.json'     >/dev/null 2>&1"
expect "t1 .mcp.json created"            test -f "$T/.mcp.json"
expect "t1 opencode.json created"        test -f "$T/opencode.json"
expect "t1 zcode.json created"           test -f "$T/zcode.json"
expect "t1 primary shape (type/command/env)" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].type == \"stdio\" and .mcpServers[\"repo-memory\"].command == \"memory\" and (.mcpServers[\"repo-memory\"].args|join(\" \")) == \"server\"' '$T/.mcp.json'"
expect "t1 sqlite default path in primary" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].env.MCP_MEMORY_SQLITE_PATH == \".ai-files/memory.db\"' '$T/.mcp.json'"
expect "t1 opencode converted (local + command array + environment)" \
    bash -c "jq -e '.mcp[\"repo-memory\"].type == \"local\" and ((.mcp[\"repo-memory\"].command)|join(\" \")) == \"memory server\" and .mcp[\"repo-memory\"].enabled == true and .mcp[\"repo-memory\"].environment.MCP_MEMORY_STORAGE_BACKEND == \"sqlite_vec\"' '$T/opencode.json'"
expect "t1 zcode converted (stdio + command scalar + environment)" \
    bash -c "jq -e '.mcp.servers[\"repo-memory\"].type == \"stdio\" and .mcp.servers[\"repo-memory\"].command == \"memory\" and (.mcp.servers[\"repo-memory\"].args|join(\" \")) == \"server\" and .mcp.servers[\"repo-memory\"].environment.PYTHONUNBUFFERED == \"1\"' '$T/zcode.json'"
expect "t1 autoApprove present in primary" \
    bash -c "jq -e '(.mcpServers[\"repo-memory\"].autoApprove | length) > 20' '$T/.mcp.json'"
expect "t1 autoApprove absent in opencode" \
    bash -c "jq -e '.mcp[\"repo-memory\"] | has(\"autoApprove\") | not' '$T/opencode.json'"
expect "t1 autoApprove absent in zcode" \
    bash -c "jq -e '.mcp.servers[\"repo-memory\"] | has(\"autoApprove\") | not' '$T/zcode.json'"

echo "=== T2: add-json + remove apply to all three files ==="
(cd "$T" && "$MCP" add-json sentry '{"transport":"http","url":"https://mcp.sentry.dev/mcp"}') >/dev/null 2>&1
expect "t2 sentry in primary"   bash -c "jq -e '.mcpServers.sentry.url == \"https://mcp.sentry.dev/mcp\"' '$T/.mcp.json'"
expect "t2 sentry in opencode (passthrough)" bash -c "jq -e '.mcp.sentry.type == \"http\"' '$T/opencode.json'"
expect "t2 sentry in zcode (passthrough)"    bash -c "jq -e '.mcp.servers.sentry.url == \"https://mcp.sentry.dev/mcp\"' '$T/zcode.json'"
(cd "$T" && "$MCP" remove sentry -y) >/dev/null 2>&1
expect "t2 sentry removed from primary"   bash -c "jq -e '.mcpServers.sentry == null' '$T/.mcp.json'"
expect "t2 sentry removed from opencode"  bash -c "jq -e '.mcp.sentry == null' '$T/opencode.json'"
expect "t2 sentry removed from zcode"     bash -c "jq -e '.mcp.servers.sentry == null' '$T/zcode.json'"
expect "t2 repo-memory still present everywhere" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"] != null' '$T/.mcp.json' && jq -e '.mcp[\"repo-memory\"] != null' '$T/opencode.json' && jq -e '.mcp.servers[\"repo-memory\"] != null' '$T/zcode.json'"

echo "=== T3: drift detection via list + repair via sync ==="
jq 'del(.mcp.servers["repo-memory"])' "$T/zcode.json" > "$BASE/z.tmp" && mv "$BASE/z.tmp" "$T/zcode.json"
LIST_OUT=$(cd "$T" && "$MCP" list)
export LIST_OUT
expect "t3 list marks repo-memory absent (-) in zcode column" \
    bash -c "printf '%s\n' \"\$LIST_OUT\" | awk '\$1==\"repo-memory\"{exit !(\$4==\"-\")}'"
(cd "$T" && "$MCP" sync -y) >/dev/null 2>&1
expect "t3 sync restores zcode entry" \
    bash -c "jq -e '.mcp.servers[\"repo-memory\"].command == \"memory\"' '$T/zcode.json'"
LIST_OUT=$(cd "$T" && "$MCP" list)
export LIST_OUT
expect "t3 list now fully in sync for repo-memory" \
    bash -c "printf '%s\n' \"\$LIST_OUT\" | awk '\$1==\"repo-memory\"{exit !(\$4==\"\xe2\x9c\x93\")}'"

echo "=== T4: secondary-only servers reported, untouched by sync ==="
jq '.mcp += {"servers":{"extra-z":{"type":"stdio","command":"foo","args":[],"enabled":true}}}' "$T/zcode.json" > "$BASE/z.tmp" && mv "$BASE/z.tmp" "$T/zcode.json"
SYNC_OUT=$(cd "$T" && "$MCP" sync -y)
export SYNC_OUT
expect "t4 sync reports extra-z but keeps it" \
    bash -c "printf '%s\n' \"\$SYNC_OUT\" | grep -q 'extra-z' && jq -e '.mcp.servers[\"extra-z\"].command == \"foo\"' '$T/zcode.json'"
(cd "$T" && "$MCP" remove extra-z -y) >/dev/null 2>&1

echo "=== T5: sibling keys preserved in pre-populated opencode.json ==="
cat > "$T/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": { "bash": { "git status": "allow" } },
  "lsp": true,
  "mcp": {}
}
JSON
(cd "$T" && "$MCP" add ssh-manager -y) >/dev/null 2>&1
expect "t5 permission preserved"  bash -c "jq -e '.permission.bash[\"git status\"] == \"allow\"' '$T/opencode.json'"
expect "t5 lsp preserved"         bash -c "jq -e '.lsp == true' '$T/opencode.json'"
expect "t5 ssh-manager added to all three" \
    bash -c "jq -e '.mcpServers[\"ssh-manager\"].command == \"mcp-ssh-manager\"' '$T/.mcp.json' && jq -e '.mcp[\"ssh-manager\"].type == \"local\"' '$T/opencode.json' && jq -e '.mcp.servers[\"ssh-manager\"].command == \"mcp-ssh-manager\"' '$T/zcode.json'"

echo "=== T6: non-nested shared-memory is a no-op ==="
(cd "$T" && "$MCP" shared-memory) >/dev/null 2>&1
expect "t6 non-nested exits 0" test $? -eq 0
(cd "$T" && "$MCP" shared-memory --check) >/dev/null 2>&1
expect "t6 --check exits 1 when not nested" test $? -eq 1

echo "=== T7: nested checkout registers directly on shared DB ==="
NEST=$BASE/premapp-backend/premapp-backend
mkdir -p "$NEST"
git -C "$NEST" init -q
(cd "$NEST" && "$MCP" add repo-memory -y) >/dev/null 2>&1
expect "t7 shared dir created under parent" test -d "$BASE/premapp-backend/.ai-files-shared"
expect "t7 primary uses shared path" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].env.MCP_MEMORY_SQLITE_PATH == \"../.ai-files-shared/memory.db\"' '$NEST/.mcp.json'"
expect "t7 opencode uses shared path" \
    bash -c "jq -e '.mcp[\"repo-memory\"].environment.MCP_MEMORY_SQLITE_PATH == \"../.ai-files-shared/memory.db\"' '$NEST/opencode.json'"

echo "=== T8: migration rewrites legacy default paths + copies db (<repo>/<clone> via remote) ==="
T8=$BASE/premapp-backend/mig-repo
mkdir -p "$T8"
git -C "$T8" init -q
git -C "$T8" remote add origin https://example.com/org/premapp-backend.git
mkdir -p "$T8/.ai-files"
printf 'x' > "$T8/.ai-files/memory.db"
cat > "$T8/.mcp.json" <<'JSON'
{ "mcpServers": { "repo-memory": { "type": "stdio", "command": "memory", "args": ["server"],
  "env": { "MCP_MEMORY_SQLITE_PATH": ".ai-files/memory.db", "MCP_MEMORY_STORAGE_BACKEND": "sqlite_vec" } } } }
JSON
cat > "$T8/opencode.json" <<'JSON'
{ "mcp": { "repo-memory": { "type": "local", "command": ["memory","server"], "enabled": true,
  "environment": { "MCP_MEMORY_SQLITE_PATH": ".ai-files/memory.db" } } } }
JSON
# custom path must be left alone:
cat > "$T8/zcode.json" <<'JSON'
{ "mcp": { "servers": { "repo-memory": { "type": "stdio", "command": "memory", "args": ["server"], "enabled": true,
  "environment": { "MCP_MEMORY_SQLITE_PATH": "custom/memory.db" } } } } }
JSON
(cd "$T8" && "$MCP" shared-memory -y) >/dev/null 2>&1
# With sqlite3 available the migration snapshots through sqlite (garbage
# fixture becomes a valid empty db); raw-copy only happens without sqlite3.
if command -v sqlite3 >/dev/null 2>&1; then
    expect "t8 shared db is a valid sqlite snapshot" \
        bash -c "sqlite3 '$BASE/premapp-backend/.ai-files-shared/memory.db' 'SELECT 1;' >/dev/null 2>&1"
else
    expect "t8 db copied into shared folder (raw fallback)" \
        cmp -s "$T8/.ai-files/memory.db" "$BASE/premapp-backend/.ai-files-shared/memory.db"
fi
expect "t8 primary rewritten" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].env.MCP_MEMORY_SQLITE_PATH == \"../.ai-files-shared/memory.db\"' '$T8/.mcp.json'"
expect "t8 opencode rewritten" \
    bash -c "jq -e '.mcp[\"repo-memory\"].environment.MCP_MEMORY_SQLITE_PATH == \"../.ai-files-shared/memory.db\"' '$T8/opencode.json'"
expect "t8 custom zcode path untouched" \
    bash -c "jq -e '.mcp.servers[\"repo-memory\"].environment.MCP_MEMORY_SQLITE_PATH == \"custom/memory.db\"' '$T8/zcode.json'"

echo "=== T8b: mismatched remote name is NOT a nested checkout ==="
T8B=$BASE/unrelated-app/any-clone
mkdir -p "$T8B"
git -C "$T8B" init -q
git -C "$T8B" remote add origin https://example.com/org/other-app.git
(cd "$T8B" && "$MCP" shared-memory) >/dev/null 2>&1
expect "t8b mismatched remote: no-op exit 0" test $? -eq 0
(cd "$T8B" && "$MCP" shared-memory --check) >/dev/null 2>&1
expect "t8b --check exits 1 when remote differs from parent dir" test $? -eq 1

echo "=== T9: unknown bare name rejected with hint ==="
OUT=$(cd "$T" && "$MCP" add nope 2>&1)
expect "t9 unknown name fails" bash -c "cd '$T' && '$MCP' add nope >/dev/null 2>&1; test \$? -ne 0"
echo "$OUT" | grep -q "Known servers registrable by name" || bad "t9 error message mentions known names"

echo "=== T11: custom servers via full 'add --transport' CLI (parser regression) ==="
T11=$BASE/t11; fresh t11
timeout 10 bash -c "cd '$T11' && '$MCP' add --transport http sentry https://mcp.sentry.dev/mcp -y" >/dev/null 2>&1
RC=$?
expect "t11 http add terminates (no parser infinite loop) and exits 0" test $RC -eq 0
expect "t11 http entry in all three configs" \
    bash -c "jq -e '.mcpServers.sentry.type == \"http\"' '$T11/.mcp.json' && jq -e '.mcp.sentry.url == \"https://mcp.sentry.dev/mcp\"' '$T11/opencode.json' && jq -e '.mcp.servers.sentry.url == \"https://mcp.sentry.dev/mcp\"' '$T11/zcode.json'"
(cd "$T11" && "$MCP" add --transport stdio git --env TOKEN=AA -- npx -y git-mcp-server) >/dev/null 2>&1
expect "t11 stdio entry with env + args in primary" \
    bash -c "jq -e '.mcpServers.git.command == \"npx\" and (.mcpServers.git.args|join(\" \")) == \"-y git-mcp-server\" and .mcpServers.git.env.TOKEN == \"AA\"' '$T11/.mcp.json'"
expect "t11 stdio entry converted in zcode (env -> environment)" \
    bash -c "jq -e '.mcp.servers.git.command == \"npx\" and (.mcp.servers.git.args|length) == 2 and .mcp.servers.git.environment.TOKEN == \"AA\"' '$T11/zcode.json'"
LIST_OUT=$(cd "$T11" && "$MCP" list)
export LIST_OUT
expect "t11 list shows both servers fully in sync" \
    bash -c "printf '%s\n' \"\$LIST_OUT\" | awk '\$1==\"git\"{exit !(\$2==\"\xe2\x9c\x93\" && \$3==\"\xe2\x9c\x93\" && \$4==\"\xe2\x9c\x93\")}' && printf '%s\n' \"\$LIST_OUT\" | awk '\$1==\"sentry\"{exit !(\$4==\"\xe2\x9c\x93\")}'"

echo "=== T10: ai-files-setup smoke run ([6/7] step present, completes cleanly) ==="
# Shim `ai-files` onto PATH pointing at the WORKTREE dispatcher, so setup's
# run_ai_files probes (mcp known/has/list) exercise these scripts, not an
# older installed copy.
SHIM=$BASE/shim; mkdir -p "$SHIM"
ln -sf "$REPO_ROOT/bin/ai-files" "$SHIM/ai-files"
TS=$BASE/setup-repo; fresh setup-repo
mkdir -p "$TS/.ai-files"   # skip heavy bootstrap step
SETUP_OUT=$(cd "$TS" && PATH="$SHIM:$PATH" "$SETUP" </dev/null 2>&1)
RC=$?
export SETUP_OUT
expect "t10 setup exits 0" test $RC -eq 0
if printf '%s' "$SETUP_OUT" | grep -q '\[6/7\]'; then ok "t10 [6/7] label printed"; else bad "t10 [6/7] label printed"; fi
# read -p prompts are suppressed without a tty, so assert on step6's analysis output:
if printf '%s' "$SETUP_OUT" | grep -q 'bootstraps the MCP config files'; then ok "t10 step6 analysis shown (.mcp.json absent)"; else bad "t10 step6 analysis shown (.mcp.json absent)"; fi
expect "t10 catalog probe via mcp known succeeded" bash -c "! printf '%s' \"\$SETUP_OUT\" | grep -q 'Cannot query known MCP servers'"
if printf '%s' "$SETUP_OUT" | grep -q '\[7/7\]'; then ok "t10 [7/7] label printed"; else bad "t10 [7/7] label printed"; fi
expect "t10 declining everything left configs untracked-safe" test ! -f "$TS/.mcp.json"

echo "=== T12: re-sync preserves secondary enabled flag ==="
T12=$BASE/t12; fresh t12
(cd "$T12" && "$MCP" add repo-memory -y) >/dev/null 2>&1
jq '.mcp["repo-memory"].enabled = false | .mcp["repo-memory"].command = ["stale-cmd"]' \
    "$T12/opencode.json" > "$BASE/o.tmp" && mv "$BASE/o.tmp" "$T12/opencode.json"
(cd "$T12" && "$MCP" sync -y) >/dev/null 2>&1
expect "t12 enabled:false preserved after drift repair" \
    bash -c "jq -e '.mcp[\"repo-memory\"].enabled == false' '$T12/opencode.json'"
expect "t12 stale command regenerated" \
    bash -c "jq -e '(.mcp[\"repo-memory\"].command)|join(\" \") == \"memory server\"' '$T12/opencode.json'"
SYNC12=$(cd "$T12" && "$MCP" sync -y)
export SYNC12
expect "t12 no churn: second sync reports in-sync despite enabled diff" \
    bash -c "printf '%s' \"\$SYNC12\" | grep -q 'already in sync'"

echo "=== T13: remove asks for confirmation (-y bypasses) ==="
T13=$BASE/t13; fresh t13
(cd "$T13" && "$MCP" add ssh-manager -y) >/dev/null 2>&1
printf 'n\n' | (cd "$T13" && "$MCP" remove ssh-manager) >/dev/null 2>&1
expect "t13 answering no aborts removal everywhere" \
    bash -c "jq -e '.mcpServers[\"ssh-manager\"] != null' '$T13/.mcp.json' && jq -e '.mcp[\"ssh-manager\"] != null' '$T13/opencode.json'"
(cd "$T13" && "$MCP" remove ssh-manager --dry-run) >/dev/null 2>&1
expect "t13 dry-run removal touches nothing" \
    bash -c "jq -e '.mcpServers[\"ssh-manager\"] != null' '$T13/.mcp.json'"
(cd "$T13" && "$MCP" remove ssh-manager -y) >/dev/null 2>&1
expect "t13 -y removes from all three" \
    bash -c "jq -e '.mcpServers[\"ssh-manager\"] == null' '$T13/.mcp.json' && jq -e '.mcp[\"ssh-manager\"] == null' '$T13/opencode.json' && jq -e '.mcp.servers[\"ssh-manager\"] == null' '$T13/zcode.json'"

echo "=== T14: pre-flight validation blocks partial multi-file updates ==="
T14=$BASE/t14; fresh t14
printf '{ this is not json' > "$T14/opencode.json"
(cd "$T14" && "$MCP" add ssh-manager -y) >/dev/null 2>&1
expect "t14 invalid secondary fails the whole add" test $? -ne 0
expect "t14 primary untouched by failed add" test ! -f "$T14/.mcp.json"
printf '{ "$schema": "https://opencode.ai/config.json", "mcp": {} }\n' > "$T14/opencode.json"
(cd "$T14" && "$MCP" add ssh-manager -y) >/dev/null 2>&1
expect "t14 succeeds once secondary is valid" \
    bash -c "jq -e '.mcpServers[\"ssh-manager\"] != null' '$T14/.mcp.json' && jq -e '.mcp[\"ssh-manager\"] != null' '$T14/opencode.json'"

echo "=== T15: db migration snapshot opens as valid sqlite with data ==="
# Isolated <repo>/<clone> pair (parent named after the repo per the detection
# rule) so this fixture owns its own .ai-files-shared.
TSQL=$BASE/otherapp/clone-one
mkdir -p "$TSQL/.ai-files"
git -C "$TSQL" init -q
git -C "$TSQL" remote add origin https://example.com/org/otherapp.git
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$TSQL/.ai-files/memory.db" "CREATE TABLE memories (id INTEGER PRIMARY KEY, content TEXT); INSERT INTO memories (content) VALUES ('migration-marker');"
    (cd "$TSQL" && "$MCP" shared-memory -y) >/dev/null 2>&1
    SHARED_DB="$BASE/otherapp/.ai-files-shared/memory.db"
    ROW=$(sqlite3 "$SHARED_DB" "SELECT content FROM memories WHERE content='migration-marker';" 2>/dev/null)
    expect "t15 migrated db is consistent sqlite containing data" test "$ROW" = "migration-marker"
    expect "t15 no -shm/-wal copied alongside snapshot" bash -c "test ! -f '$SHARED_DB-shm' && test ! -f '$SHARED_DB-wal'"
else
    echo "SKIP t15 (sqlite3 unavailable)"
fi

echo "=== T16: memory-path env-driven rewrite + git-config pin ==="
T16=$BASE/t16; fresh t16
(cd "$T16" && "$MCP" add repo-memory -y) >/dev/null 2>&1
expect "t16 first check in sync (primary adopted as canonical)" \
    bash -c "cd '$T16' && '$MCP' memory-path --check"
# --check never writes; a plain run seeds aifiles.memory-db-path silently
(cd "$T16" && "$MCP" memory-path -y) >/dev/null 2>&1
expect "t16 git config seeded to absolute default path" \
    test "$(git -C "$T16" config --local aifiles.memory-db-path)" = "$T16/.ai-files/memory.db"
NEW16="$T16/shared/memory2.db"
expect "t16 check exits 1 when env var points elsewhere" \
    bash -c "cd '$T16' && MCP_MEMORY_SQLITE_PATH='$NEW16' '$MCP' memory-path --check >/dev/null 2>&1; test \$? -eq 1"
mkdir -p "$T16/shared"
(cd "$T16" && MCP_MEMORY_SQLITE_PATH="$NEW16" "$MCP" memory-path -y) >/dev/null 2>&1
expect "t16 all three configs rewritten to env path" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].env.MCP_MEMORY_SQLITE_PATH == \"$NEW16\"' '$T16/.mcp.json' && jq -e '.mcp[\"repo-memory\"].environment.MCP_MEMORY_SQLITE_PATH == \"$NEW16\"' '$T16/opencode.json' && jq -e '.mcp.servers[\"repo-memory\"].environment.MCP_MEMORY_SQLITE_PATH == \"$NEW16\"' '$T16/zcode.json'"
expect "t16 git config pinned to new absolute path" \
    test "$(git -C "$T16" config --local aifiles.memory-db-path)" = "$NEW16"
expect "t16 check in sync again with env set" \
    bash -c "cd '$T16' && MCP_MEMORY_SQLITE_PATH='$NEW16' '$MCP' memory-path --check"
expect "t16 relative env value compares equivalent (no spurious drift)" \
    bash -c "cd '$T16' && MCP_MEMORY_SQLITE_PATH='shared/memory2.db' '$MCP' memory-path --check"

echo "=== T17: memory-path repairs drift from stored value (no env) ==="
T17=$BASE/t17; fresh t17
(cd "$T17" && "$MCP" add repo-memory -y) >/dev/null 2>&1
NEW17="$T17/shared/new.db"
(cd "$T17" && MCP_MEMORY_SQLITE_PATH="$NEW17" "$MCP" memory-path -y) >/dev/null 2>&1
jq '.mcp.servers["repo-memory"].environment.MCP_MEMORY_SQLITE_PATH = ".ai-files/memory.db"' \
    "$T17/zcode.json" > "$BASE/z17.tmp" && mv "$BASE/z17.tmp" "$T17/zcode.json"
(cd "$T17" && "$MCP" memory-path --check) >/dev/null 2>&1
expect "t17 --check detects drift without env var" test $? -eq 1
(cd "$T17" && "$MCP" memory-path -y) >/dev/null 2>&1
expect "t17 drifted zcode restored to stored path" \
    bash -c "jq -e '.mcp.servers[\"repo-memory\"].environment.MCP_MEMORY_SQLITE_PATH == \"$NEW17\"' '$T17/zcode.json'"
expect "t17 back in sync" bash -c "cd '$T17' && '$MCP' memory-path --check"

# --- shared fixtures for memory-import tests ---------------------------------
# MEMFIX builds minimal mcp-memory-service-shaped DBs (memories + graph +
# beliefs + FTS5, no vec0 table — the documented raw-mode degraded path, so
# no sqlite3 CLI / service install is needed). AIFILES_MEMIMPORT_REEXEC=1 in
# the invocations below pins the helper to that raw mode for determinism on
# hosts that DO have the mcp-memory-service pipx env.
MEMFIX="$BASE/memfix.py"
cat > "$MEMFIX" <<'MEMFIX_EOF'
import sqlite3, hashlib, json, sys

def chash(s):
    return hashlib.sha256(s.strip().lower().encode()).hexdigest()

def mkdb(path, mems, edges, beliefs):
    c = sqlite3.connect(path)
    c.executescript("""
    CREATE TABLE memories (id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_hash TEXT UNIQUE NOT NULL, content TEXT NOT NULL, tags TEXT,
        memory_type TEXT, metadata TEXT, created_at REAL, updated_at REAL,
        created_at_iso TEXT, updated_at_iso TEXT, deleted_at REAL, store TEXT,
        parent_id TEXT, version INTEGER DEFAULT 1, confidence REAL DEFAULT 1.0,
        last_accessed INTEGER, superseded_by TEXT);
    CREATE TABLE memory_graph (source_hash TEXT NOT NULL, target_hash TEXT NOT NULL,
        similarity REAL NOT NULL, connection_types TEXT NOT NULL, metadata TEXT,
        created_at REAL NOT NULL, relationship_type TEXT DEFAULT 'related',
        PRIMARY KEY (source_hash, target_hash));
    CREATE TABLE beliefs (id INTEGER PRIMARY KEY AUTOINCREMENT,
        belief_hash TEXT UNIQUE NOT NULL, content TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.5, status TEXT NOT NULL DEFAULT 'candidate',
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        derived_from TEXT NOT NULL DEFAULT '[]', contradicted_by TEXT NOT NULL DEFAULT '[]',
        metadata TEXT DEFAULT '{}');
    CREATE VIRTUAL TABLE memory_content_fts USING fts5(content, content='memories',
        content_rowid='id');
    CREATE TRIGGER memories_fts_ai AFTER INSERT ON memories BEGIN
        INSERT INTO memory_content_fts(rowid, content) VALUES (new.id, new.content); END;
    """)
    for text, tags in mems:
        c.execute("INSERT INTO memories (content_hash, content, tags) VALUES (?,?,?)",
                  (chash(text), text, tags))
    for a, b in edges:
        c.execute("INSERT INTO memory_graph (source_hash, target_hash, similarity, "
                  "connection_types, created_at) VALUES (?,?,?,'[]',1.0)",
                  (chash(a), chash(b), 0.9))
    for b in beliefs:
        c.execute("INSERT INTO beliefs (belief_hash, content, created_at, updated_at) "
                  "VALUES (?,?,'x','x')", (chash(b), b))
    c.commit(); c.close()

mkdb(sys.argv[1], json.loads(sys.argv[2]), json.loads(sys.argv[3]), json.loads(sys.argv[4]))
MEMFIX_EOF
qdb() { # qdb <db> <sql> -> first column of first row
    python3 -c 'import sqlite3,sys
print(sqlite3.connect(sys.argv[1]).execute(sys.argv[2]).fetchone()[0])' "$1" "$2" 2>/dev/null
}

echo "=== T18: import offered+run when path changes and both DBs exist ==="
T18=$BASE/t18; fresh t18
(cd "$T18" && "$MCP" add repo-memory -y) >/dev/null 2>&1
mkdir -p "$T18/.ai-files"
OLD18="$T18/.ai-files/memory.db"
NEW18="$T18/shared/memory2.db"; mkdir -p "$T18/shared"
python3 "$MEMFIX" "$OLD18" \
    '[["alpha memory one","t1"],["shared memory","t3"]]' \
    '[["alpha memory one","shared memory"],["alpha memory one","missing endpoint"]]' \
    '["belief one"]'
python3 "$MEMFIX" "$NEW18" \
    '[["shared memory","dest"],["gamma memory three","dest"]]' '[]' '[]'
(cd "$T18" && AIFILES_MEMIMPORT_REEXEC=1 MCP_MEMORY_SQLITE_PATH="$NEW18" "$MCP" memory-path -y) >/dev/null 2>&1
expect "t18 path change executed cleanly" test $? -eq 0
expect "t18 dedup held: 3 memories in target" \
    test "$(qdb "$NEW18" 'SELECT count(*) FROM memories')" = "3"
TAGS18=$(qdb "$NEW18" "SELECT tags FROM memories WHERE content='alpha memory one'")
if printf '%s' "$TAGS18" | grep -q 'imported:'; then ok "t18 provenance tag on imported row"; else bad "t18 provenance tag on imported row ($TAGS18)"; fi
META18=$(qdb "$NEW18" "SELECT metadata FROM memories WHERE content='alpha memory one'")
if printf '%s' "$META18" | grep -q 'merge_id'; then ok "t18 merge_id recorded in metadata"; else bad "t18 merge_id recorded in metadata ($META18)"; fi
expect "t18 complete edge merged, dangling skipped" \
    test "$(qdb "$NEW18" 'SELECT count(*) FROM memory_graph')" = "1"
expect "t18 belief merged" \
    test "$(qdb "$NEW18" 'SELECT count(*) FROM beliefs')" = "1"
FTS18=$(qdb "$NEW18" "SELECT count(*) FROM memory_content_fts WHERE memory_content_fts MATCH 'alpha'")
expect "t18 FTS index covers imported content" test "$FTS18" -ge 1
expect "t18 configs now use the new path" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].env.MCP_MEMORY_SQLITE_PATH == \"$NEW18\"' '$T18/.mcp.json'"

echo "=== T19: standalone memory-import (dry-run default, --execute, errors) ==="
T19=$BASE/t19; fresh t19
(cd "$T19" && "$MCP" add repo-memory -y) >/dev/null 2>&1
mkdir -p "$T19/.ai-files"
S19=$BASE/src19.db; D19=$BASE/dst19.db
python3 "$MEMFIX" "$S19" '[["one","a"],["two","a"]]' '[["one","two"]]' '[]'
python3 "$MEMFIX" "$D19" '[["two","b"],["three","b"]]' '[]' '[]'
python3 "$MEMFIX" "$T19/.ai-files/memory.db" '[["nine","n"]]' '[]' '[]'
OUT19=$( (cd "$T19" && AIFILES_MEMIMPORT_REEXEC=1 "$MCP" memory-import "$S19" "$D19") 2>&1)
if printf '%s' "$OUT19" | grep -q 'DRY-RUN'; then ok "t19 default run is a dry-run"; else bad "t19 default run is a dry-run"; fi
expect "t19 dry-run left target unchanged" \
    test "$(qdb "$D19" 'SELECT count(*) FROM memories')" = "2"
(cd "$T19" && AIFILES_MEMIMPORT_REEXEC=1 "$MCP" memory-import "$S19" "$D19" --execute) >/dev/null 2>&1
expect "t19 execute merged with dedup" \
    test "$(qdb "$D19" 'SELECT count(*) FROM memories')" = "3"
(cd "$T19" && AIFILES_MEMIMPORT_REEXEC=1 "$MCP" memory-import "$S19" --execute) >/dev/null 2>&1
expect "t19 omitted target defaults to configured DB path" \
    test "$(qdb "$T19/.ai-files/memory.db" 'SELECT count(*) FROM memories')" = "3"
expect_fail "t19 missing source fails" \
    bash -c "cd '$T19' && AIFILES_MEMIMPORT_REEXEC=1 '$MCP' memory-import '$BASE/no-such.db' '$D19'"
expect_fail "t19 missing target fails" \
    bash -c "cd '$T19' && AIFILES_MEMIMPORT_REEXEC=1 '$MCP' memory-import '$S19' '$BASE/no-target.db'"

echo "=== T20: aifiles.memory-db-path managed via ai-files-config ==="
T20=$BASE/t20; fresh t20
CFG="$REPO_ROOT/bin/ai-files-config"
(cd "$T20" && "$CFG" set memory-db-path /tmp/x.db) >/dev/null 2>&1
expect "t20 set memory-db-path" \
    test "$(git -C "$T20" config --local aifiles.memory-db-path)" = "/tmp/x.db"
expect "t20 get memory-db-path" \
    bash -c "cd '$T20' && '$CFG' get memory-db-path | grep -q '/tmp/x.db'"
(cd "$T20" && "$CFG" unset memory-db-path) >/dev/null 2>&1
expect "t20 unset clears key" \
    test -z "$(git -C "$T20" config --local aifiles.memory-db-path 2>/dev/null || true)"
expect_fail "t20 unknown key still rejected" \
    bash -c "cd '$T20' && '$CFG' set bogus-key v"

echo "=== T21: ai-files-setup realigns via memory-path (drift prompt, decline-safe) ==="
T21=$BASE/t21; fresh t21
mkdir -p "$T21/.ai-files"
(cd "$T21" && PATH="$SHIM:$PATH" "$MCP" add repo-memory -y) >/dev/null 2>&1
OLD21="$T21/.ai-files/memory.db"; NEW21="$T21/shared/memory2.db"
mkdir -p "$T21/shared"
python3 "$MEMFIX" "$OLD21" '[["one","a"]]' '[]' '[]'
python3 "$MEMFIX" "$NEW21" '[["two","b"]]' '[]' '[]'
SETUP_OUT21=$( (cd "$T21" && PATH="$SHIM:$PATH" AIFILES_MEMIMPORT_REEXEC=1 \
    MCP_MEMORY_SQLITE_PATH="$NEW21" "$SETUP") </dev/null 2>&1)
RC=$?
export SETUP_OUT21
expect "t21 setup exits 0 with env var set" test $RC -eq 0
# read -p prompts are suppressed without a tty, so the drift branch is proven
# by its decline message + the ABSENCE of the in-sync message the --check-ok
# path would print.
if printf '%s' "$SETUP_OUT21" | grep -q 'Keeping current memory DB paths'; then ok "t21 drift branch reached and declined (EOF default-no)"; else bad "t21 drift branch reached and declined"; fi
if printf '%s' "$SETUP_OUT21" | grep -q 'Memory DB path already in sync'; then bad "t21 drift was NOT detected (in-sync message present)"; else ok "t21 drift detected (no in-sync message)"; fi
expect "t21 configs NOT rewritten after decline" \
    bash -c "jq -e '.mcpServers[\"repo-memory\"].env.MCP_MEMORY_SQLITE_PATH == \".ai-files/memory.db\"' '$T21/.mcp.json'"

echo "=== T22: memory-import SERVICE mode via pipx env (embedding copy) ==="
# Real service-mode coverage: no AIFILES_MEMIMPORT_REEXEC guard here, so the
# helper auto-detects the pipx venv, re-execs into it, and copies embeddings
# through the sqlite-vec extension. CI installs the package via pipx
# (.github/workflows/tests.yml); hosts without it SKIP (T15 sqlite3 pattern).
PIPX_PY="$HOME/.local/pipx/venvs/mcp-memory-service/bin/python"
# When pipx's home is relocated, fall back to the `memory` CLI's interpreter
# (pipx entry scripts carry the venv python in their shebang).
if [[ ! -x "$PIPX_PY" ]] && command -v memory >/dev/null 2>&1; then
    CAND22=$(head -1 "$(command -v memory)" | sed 's/^#!//' | cut -d' ' -f1)
    [[ "$CAND22" == *python* && -x "$CAND22" ]] && PIPX_PY="$CAND22"
fi
if [[ -x "$PIPX_PY" ]]; then
    T22=$BASE/t22; fresh t22
    (cd "$T22" && "$MCP" add repo-memory -y) >/dev/null 2>&1
    S22=$BASE/src22.db; D22=$BASE/dst22.db
    "$PIPX_PY" - "$S22" "$D22" <<'PY22'
import sqlite3, sqlite_vec, hashlib, struct, sys

def chash(s):
    return hashlib.sha256(s.strip().lower().encode()).hexdigest()

def mkdb(path, contents):
    c = sqlite3.connect(path)
    c.enable_load_extension(True); sqlite_vec.load(c); c.enable_load_extension(False)
    c.executescript("""CREATE TABLE memories (id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_hash TEXT UNIQUE NOT NULL, content TEXT NOT NULL, tags TEXT);
    CREATE VIRTUAL TABLE memory_embeddings USING vec0(
        content_embedding FLOAT[384] distance_metric=cosine, store TEXT partition key);""")
    for text in contents:
        cur = c.execute("INSERT INTO memories (content_hash, content) VALUES (?,?)",
                        (chash(text), text))
        seed = int(chash(text)[:8], 16)
        c.execute("INSERT INTO memory_embeddings (rowid, content_embedding, store) "
                  "VALUES (?,?, 'default')",
                  (cur.lastrowid, struct.pack("384f",
                      *[((seed >> (k % 32)) & 1) - 0.5 for k in range(384)])))
    c.commit(); c.close()

mkdb(sys.argv[1], ["t22 alpha", "t22 shared"])
mkdb(sys.argv[2], ["t22 shared", "t22 gamma"])
PY22
    expect "t22 helper env probe succeeds" "$REPO_ROOT/bin/ai-files-mcp-memory-import" --check-env
    OUT22=$( (cd "$T22" && "$MCP" memory-import "$S22" "$D22" --execute) 2>&1)
    export OUT22
    expect "t22 service mode selected (copy plan, not raw)" \
        bash -c "printf '%s' \"\$OUT22\" | grep -q 'copy (384-dim, service mode)'"
    qdb22() { "$PIPX_PY" -c 'import sqlite3, sqlite_vec, sys
c = sqlite3.connect(sys.argv[1])
c.enable_load_extension(True); sqlite_vec.load(c); c.enable_load_extension(False)
print(c.execute(sys.argv[2]).fetchone()[0])' "$1" "$2" 2>/dev/null; }
    expect "t22 dedup held in service mode" \
        test "$(qdb22 "$D22" 'SELECT count(*) FROM memories')" = "3"
    expect "t22 embeddings copied with rowid remap" \
        test "$(qdb22 "$D22" 'SELECT count(*) FROM memory_embeddings')" = "3"
else
    echo "SKIP t22 (mcp-memory-service pipx env not installed)"
fi

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
