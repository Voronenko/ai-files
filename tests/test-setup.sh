#!/usr/bin/env bash
# Test suite for `ai-files setup` graphify step-4 behavior: git-hook
# detection/install and graph indexing offer.
#
# Conventions match tests/run-tests.sh: fixtures live in a self-cleaning
# mktemp workspace, PASS/FAIL counters, exit 1 on any failure.
#
# Hermetic: `graphify` and `ai-files` are stubbed onto a minimal PATH (real
# graphify never runs); stdin is piped or /dev/null so a stray prompt surfaces
# as EOF-driven default-no, never a hang.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$REPO_ROOT/bin/ai-files-setup"

if [[ ! -x "$SETUP" ]]; then
    echo "ERROR: missing executable: $SETUP" >&2
    exit 2
fi
for cmd in git yes; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-setup-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

fresh() { # fresh <dir> — new git repo with the graphify backend preset (skips
           # step 4b's interactive backend selector; graphify itself is stubbed)
    rm -rf "${BASE:?}/$1"
    mkdir -p "$BASE/$1"
    git -C "$BASE/$1" init -q
    git -C "$BASE/$1" config aifiles.graphify-backend claude
}

# Recording stubs. One shared call log (truncated per scenario) and a state
# dir whose hooks-installed marker drives `hook status` output.
STUBS="$BASE/stubs"; STUB_STATE="$BASE/stub-state"
mkdir -p "$STUBS" "$STUB_STATE"
STUB_LOG="$BASE/stub.log"; export STUB_LOG STUB_STATE

cat > "$STUBS/ai-files" <<'EOF'
#!/usr/bin/env bash
echo "ai-files $*" >> "$STUB_LOG"
exit 0
EOF
cat > "$STUBS/graphify" <<'EOF'
#!/usr/bin/env bash
echo "graphify $*" >> "$STUB_LOG"
case "$1 $2" in
    "hook status")
        if [[ -f "$STUB_STATE/hooks-installed" ]]; then
            echo "post-commit: installed"
            echo "post-checkout: installed"
            echo "merge driver: registered"
        else
            echo "post-commit: not installed"
            echo "post-checkout: not installed"
            echo "merge driver: not registered"
        fi
        ;;
    "hook install")
        touch "$STUB_STATE/hooks-installed"
        echo "stub: installed graphify hooks"
        ;;
esac
exit 0
EOF
chmod +x "$STUBS/ai-files" "$STUBS/graphify"

# Minimal PATH: stubs + coreutils/git only — no real graphify, codegraph,
# ollama or fzf, mirroring a clean CI runner.
HERMETIC="$STUBS:/usr/bin:/bin"

run_setup() { # run_setup <dir> <stdin-mode: yes|no|null>
    (cd "$BASE/$1" && PATH="$HERMETIC" "$SETUP" \
        < <(case "$2" in yes) yes ;; no) yes n ;; null) cat /dev/null ;; esac) \
        2>&1)
}

echo "=== S1: fresh repo, answers yes — hooks installed, graph indexed ==="
T=s1; fresh "$T"; : > "$STUB_LOG"
S1_OUT="$(run_setup "$T" yes)"; RC=$?
export S1_OUT
expect "s1 exits 0" test "$RC" -eq 0
expect "s1 ran 'graphify hook install'" grep -qx "graphify hook install" "$STUB_LOG"
expect "s1 ran 'ai-files graphify .'" grep -qx "ai-files graphify ." "$STUB_LOG"
expect "s1 success: hooks installed" \
    bash -c "printf '%s' \"\$S1_OUT\" | grep -q 'graphify hooks installed'"
expect "s1 success: graph built" \
    bash -c "printf '%s' \"\$S1_OUT\" | grep -q 'graphify graph built'"

echo "=== S2: hooks installed + graph present — both checks short-circuit ==="
T=s2; fresh "$T"
touch "$STUB_STATE/hooks-installed"
mkdir -p "$BASE/$T/graphify-out"; echo '{}' > "$BASE/$T/graphify-out/graph.json"
: > "$STUB_LOG"
S2_OUT="$(run_setup "$T" null)"; RC=$?
export S2_OUT
expect "s2 exits 0" test "$RC" -eq 0
expect "s2 did not call graphify hook install" \
    bash -c "! grep -q '^graphify hook install' '$STUB_LOG'"
expect "s2 did not re-index" bash -c "! grep -q '^ai-files graphify' '$STUB_LOG'"
expect "s2 reports hooks already installed" \
    bash -c "printf '%s' \"\$S2_OUT\" | grep -q 'graphify hooks already installed'"
expect "s2 reports graph exists" \
    bash -c "printf '%s' \"\$S2_OUT\" | grep -q 'graph exists'"

echo "=== S3: graphify binary absent — skip messages, no crash ==="
rm -f "$STUB_STATE/hooks-installed"
T=s3; fresh "$T"
git -C "$BASE/$T" config --unset aifiles.graphify-backend
: > "$STUB_LOG"
S3_OUT="$(cd "$BASE/$T" && PATH="${STUBS%/stubs}:/usr/bin:/bin" "$SETUP" \
    </dev/null 2>&1)"; RC=$?
export S3_OUT
expect "s3 exits 0" test "$RC" -eq 0
expect "s3 skips backend selection" \
    bash -c "printf '%s' \"\$S3_OUT\" | grep -q 'skipping backend selection'"
expect "s3 skips hook check" \
    bash -c "printf '%s' \"\$S3_OUT\" | grep -q 'skipping hook check'"
expect "s3 skips indexing (EOF default-no)" \
    bash -c "printf '%s' \"\$S3_OUT\" | grep -q 'Skipping graphify indexing'"
expect "s3 never called graphify" bash -c "! grep -q '^graphify' '$STUB_LOG'"

echo "=== S4: answers no — both offers declined, nothing invoked ==="
T=s4; fresh "$T"; : > "$STUB_LOG"
S4_OUT="$(run_setup "$T" no)"; RC=$?
export S4_OUT
expect "s4 exits 0" test "$RC" -eq 0
expect "s4 declines hooks" \
    bash -c "printf '%s' \"\$S4_OUT\" | grep -q 'Skipping graphify hooks'"
expect "s4 declines indexing" \
    bash -c "printf '%s' \"\$S4_OUT\" | grep -q 'Skipping graphify indexing'"
expect "s4 never called graphify hook install" \
    bash -c "! grep -q '^graphify hook install' '$STUB_LOG'"
expect "s4 never indexed" bash -c "! grep -q '^ai-files graphify' '$STUB_LOG'"

echo "=== S5: help documents the new step-4 actions ==="
HELP_OUT="$("$SETUP" -h 2>&1)"
echo "$HELP_OUT" | grep -q "graphify hook install" && ok "s5 help lists hook install" || bad "s5 help lists hook install"
echo "$HELP_OUT" | grep -q "ai-files graphify ." && ok "s5 help lists indexing command" || bad "s5 help lists indexing command"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
