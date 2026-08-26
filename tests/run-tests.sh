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
    rm -rf "$BASE/$1"
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

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
