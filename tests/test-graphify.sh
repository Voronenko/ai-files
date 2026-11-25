#!/usr/bin/env bash
# Test suite for `ai-files-graphify` — the wrapper that applies
# aifiles.graphify-backend / aifiles.graphify-model from git config.
#
# Covers the contract that makes 'ai-files graphify .' respect the configured
# local ollama model: LLM subcommands get --backend/--model injected, non-LLM
# subcommands (hook install, update, query, ...) pass through untouched.
#
# GRAPHIFY_BIN is pointed at a recording stub — the real graphify binary is
# never needed, so the suite runs on a bare CI runner. Stub output: line 1 =
# exec argv joined with ';' (original args first, injected flags last),
# line 2 = OLLAMA_API_KEY.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAPHIFY="$REPO_ROOT/bin/ai-files-graphify"

if [[ ! -x "$GRAPHIFY" ]]; then
    echo "ERROR: missing executable: $GRAPHIFY" >&2
    exit 2
fi
command -v git >/dev/null 2>&1 || { echo "ERROR: missing git" >&2; exit 2; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
# has <desc> <haystack> <pattern> — grep -q in the parent shell (no bash -c:
# helper functions are invisible to child shells).
has() {
    local desc="$1" haystack="$2" pattern="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then ok "$desc"; else bad "$desc"; fi
}
lacks() {
    local desc="$1" haystack="$2" pattern="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then bad "$desc"; else ok "$desc"; fi
}

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-graphify-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

fresh() { # fresh <dir> [backend] [model]
    rm -rf "${BASE:?}/$1"
    mkdir -p "$BASE/$1"
    git -C "$BASE/$1" init -q
    [ -n "${2:-}" ] && git -C "$BASE/$1" config aifiles.graphify-backend "$2"
    [ -n "${3:-}" ] && git -C "$BASE/$1" config aifiles.graphify-model "$3"
}

STUBS="$BASE/stubs"; mkdir -p "$STUBS"
cat > "$STUBS/rec" <<'EOF'
#!/usr/bin/env bash
IFS=';'
printf '%s\n' "$*"
printf '%s\n' "OLLAMA_API_KEY=${OLLAMA_API_KEY:-}"
EOF
chmod +x "$STUBS/rec"

run_wrap() { # run_wrap <dir> <args...> — stub argv + key capture
    (cd "$BASE/$1" && PATH="$STUBS:$PATH" GRAPHIFY_BIN=rec "$GRAPHIFY" "${@:2}" 2>/dev/null)
}
argv_of() { head -1 <<<"$1"; }
key_of()  { tail -1 <<<"$1"; }
count_in() { printf '%s\n' "$1" | grep -o -- "$2" | wc -l; } # haystack, token

echo "=== G1: bare path (extract) gets backend+model injected ==="
fresh g1 ollama-local glm-4.7-flash
OUT="$(run_wrap g1 .)"
has "g1 backend injected" "$(argv_of "$OUT")" --'backend;ollama-local'
has "g1 model injected" "$(argv_of "$OUT")" --'model;glm-4.7-flash'
has "g1 path preserved" "$(argv_of "$OUT")" '^\.;'
has "g1 injected after path" "$(argv_of "$OUT")" '\.;--backend;ollama-local;--model;glm-4.7-flash$'

echo "=== G2: extract/label/cluster-only are LLM commands; others passthrough ==="
fresh g2 claude sonnet
for sub in "extract;src" "label;." "cluster-only;."; do
    OUT="$(run_wrap g2 "${sub//;/ }")"
    has "g2 $sub injected" "$(argv_of "$OUT")" --'backend;claude'
done
for sub in "hook install" "update ." "query what" "version" "install --platform claude"; do
    # shellcheck disable=SC2086 — sub deliberately word-split
    OUT="$(run_wrap g2 $sub)"
    lacks "g2 passthrough: $sub" "$(argv_of "$OUT")" --'backend'
done

echo "=== G3: explicit flags never doubled ==="
fresh g3 deepseek m2
OUT="$(run_wrap g3 extract . --backend mine)"
[ "$(count_in "$(argv_of "$OUT")" '--backend')" -eq 1 ] \
    && ok "g3 explicit --backend kept single" || bad "g3 explicit --backend kept single"
OUT="$(run_wrap g3 extract . --model=mymodel)"
[ "$(count_in "$(argv_of "$OUT")" '--model')" -eq 1 ] \
    && ok "g3 explicit --model= kept single" || bad "g3 explicit --model= kept single"
OUT="$(run_wrap g3 extract . --backend mine)"
has "g3 explicit backend value survives" "$(argv_of "$OUT")" --'backend;mine'
lacks "g3 config backend not added" "$(argv_of "$OUT")" --'backend;deepseek'

echo "=== G4: ollama backends export OLLAMA_API_KEY, others do not ==="
fresh g4 ollama-local m
has "g4 ollama-local sets key" "$(key_of "$(run_wrap g4 .)")" 'OLLAMA_API_KEY=ollama$'
fresh g4b ollama m
has "g4 builtin ollama sets key" "$(key_of "$(run_wrap g4b .)")" 'OLLAMA_API_KEY=.'
fresh g4c claude ""
lacks "g4 non-ollama leaves key unset" "$(key_of "$(run_wrap g4c .)")" 'OLLAMA_API_KEY=.'

echo "=== G5: no git config (or no repo) = plain passthrough ==="
fresh g5
OUT="$(run_wrap g5 extract .)"
lacks "g5 unset config injects nothing" "$(argv_of "$OUT")" --'backend'
mkdir -p "$BASE/norepo"
OUT="$(cd "$BASE/norepo" && PATH="$STUBS:$PATH" GRAPHIFY_BIN=rec "$GRAPHIFY" extract . 2>/dev/null)"
lacks "g5 outside repo passthrough" "$(argv_of "$OUT")" --'backend'

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
