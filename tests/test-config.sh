#!/usr/bin/env bash
# Test suite for `ai-files config` (list/get/set/unset + unattended setup).
#
# Conventions match tests/run-tests.sh: fixtures live in a self-cleaning
# mktemp workspace, PASS/FAIL counters, exit 1 on any failure.
#
# Interactive-free guarantees: every setup invocation runs unattended and with
# stdin </dev/null — a stray prompt would surface as EOF-driven failure.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$REPO_ROOT/bin/ai-files-config"

if [[ ! -x "$CFG" ]]; then
    echo "ERROR: missing executable: $CFG" >&2
    exit 2
fi
for cmd in git jq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-config-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

fresh() { # fresh <dir> [remote-url]
    rm -rf "${BASE:?}/$1"
    mkdir -p "$BASE/$1"
    git -C "$BASE/$1" init -q
    if [ -n "${2:-}" ]; then
        git -C "$BASE/$1" remote add origin "$2"
    fi
}

cfgget() { (cd "$BASE/$1" && "$CFG" get "$2" 2>/dev/null); }

# Fake obsidian CLI exercising the soft-verification path.
SHIMBIN="$BASE/shims"
mkdir -p "$SHIMBIN"
cat > "$SHIMBIN/obsidian" <<'EOF'
#!/usr/bin/env bash
printf 'myvault\t/tmp/vaults/myvault\nworkvault\t/tmp/vaults/workvault\n'
EOF
chmod +x "$SHIMBIN/obsidian"

# Hermetic PATH dir: git only, NO obsidian, NO fzf — proves setup never needs them.
GITONLY="$BASE/gitonly"
mkdir -p "$GITONLY"
ln -sf "$(command -v git)" "$GITONLY/git"
ln -sf /usr/bin/env "$GITONLY/env"
ln -sf "$(command -v bash)" "$GITONLY/bash"

echo "=== C1: list on clean repo shows header + NOT SET hints ==="
T=$BASE/c1; fresh c1
C1_OUT=$(cd "$T" && "$CFG" list)
export C1_OUT
expect "c1 exits 0" test $? -eq 0
expect "c1 header mentions aifiles config" \
    bash -c "printf '%s\n' \"\$C1_OUT\" | grep -q 'aifiles config'"
expect "c1 session path NOT SET hint" \
    bash -c "printf '%s\n' \"\$C1_OUT\" | grep -q 'vault-session-default-path.*NOT SET'"

echo "=== C2: set/get round-trip + unknown key rejection ==="
(cd "$T" && "$CFG" set vault my-vault) >/dev/null 2>&1
expect "c2 set+get vault round-trip" test "$(cfgget c1 vault)" = "my-vault"
(cd "$T" && "$CFG" set project-slug org/app) >/dev/null 2>&1
expect "c2 slug round-trip" test "$(cfgget c1 project-slug)" = "org/app"
expect "c2 unknown key rejected" bash -c "cd '$T' && '$CFG' set nope x >/dev/null 2>&1; test \$? -ne 0"
OUT=$(cd "$T" && "$CFG" set nope x 2>&1)
echo "$OUT" | grep -q "known keys" && ok "c2 error lists known keys" || bad "c2 error lists known keys"
expect "c2 unset removes key" bash -c "cd '$T' && '$CFG' unset project-slug >/dev/null 2>&1 && ! '$CFG' get project-slug >/dev/null 2>&1"
OUT=$(cd "$T" && "$CFG" unset project-slug 2>&1)
echo "$OUT" | grep -q "not set" && ok "c2 double-unset reports not set" || bad "c2 double-unset reports not set"

echo "=== C3: unattended setup, fully explicit, WITHOUT obsidian on PATH ==="
TC=$BASE/c3; fresh c3 "https://example.com/org/premapp-backend.git"
OUT=$(cd "$TC" && PATH="$GITONLY:/usr/bin:/bin" "$CFG" setup \
    --vault my-vault --project-slug org/app \
    --vault-default-path pages/org/app/repo-x \
    --vault-session-default-path sessions-x \
    --vault-memory-default-path memory-x </dev/null 2>&1)
export OUT
expect "c3 exits 0" test $? -eq 0
expect "c3 vault stored"            test "$(cfgget c3 vault)" = "my-vault"
expect "c3 slug stored"             test "$(cfgget c3 project-slug)" = "org/app"
expect "c3 default path stored"     test "$(cfgget c3 vault-default-path)" = "pages/org/app/repo-x"
expect "c3 session path stored"     test "$(cfgget c3 vault-session-default-path)" = "sessions-x"
expect "c3 memory path stored"      test "$(cfgget c3 vault-memory-default-path)" = "memory-x"

echo "=== C4: minimal unattended derives paths from origin remote ==="
TD=$BASE/c4; fresh c4 "https://example.com/org/premapp-backend"
OUT=$(cd "$TD" && PATH="$SHIMBIN:$PATH" "$CFG" setup --vault myvault </dev/null 2>&1)
expect "c4 exits 0 (fake obsidian present, no prompts)" test $? -eq 0
expect "c4 default path derived with slug-less formula" \
    test "$(cfgget c4 vault-default-path)" = "pages/repo-premapp-backend"
expect "c4 session path derived" \
    test "$(cfgget c4 vault-session-default-path)" = "pages/repo-premapp-backend/sessions"
expect "c4 memory path derived" \
    test "$(cfgget c4 vault-memory-default-path)" = "pages/repo-premapp-backend/memory"
expect "c4 slug skipped when unknown" \
    bash -c "cd '$BASE/c4' && ! '$CFG' get project-slug >/dev/null 2>&1"

echo "=== C5: preset memory-path preference survives re-run ==="
(cd "$TD" && "$CFG" set vault-memory-default-path custom/mem) >/dev/null 2>&1
(cd "$TD" && PATH="$SHIMBIN:$PATH" "$CFG" setup --vault myvault </dev/null) >/dev/null 2>&1
expect "c5 custom memory path kept" test "$(cfgget c4 vault-memory-default-path)" = "custom/mem"

echo "=== C6: -y without any vault fails with actionable hint ==="
TE=$BASE/c6; fresh c6
(cd "$TE" && PATH="$GITONLY:/usr/bin:/bin" "$CFG" setup -y </dev/null) >/dev/null 2>&1
expect "c6 exits non-zero" test $? -ne 0
OUT=$(cd "$TE" && PATH="$GITONLY:/usr/bin:/bin" "$CFG" setup -y </dev/null 2>&1)
echo "$OUT" | grep -q "\-\-vault" && ok "c6 hint mentions --vault" || bad "c6 hint mentions --vault"
expect "c6 failed run left config empty" bash -c "cd '$TE' && ! '$CFG' get vault >/dev/null 2>&1"

echo "=== C7: rerun is idempotent ==="
V_BEFORE="$(cfgget c3 vault-default-path)"
(cd "$TC" && PATH="$GITONLY:/usr/bin:/bin" "$CFG" setup \
    --vault my-vault --project-slug org/app \
    --vault-default-path pages/org/app/repo-x \
    --vault-session-default-path sessions-x \
    --vault-memory-default-path memory-x </dev/null) >/dev/null 2>&1
expect "c7 second run keeps values" test "$(cfgget c3 vault-default-path)" = "$V_BEFORE"

echo "=== C8: help documents unattended options ==="
HELP_OUT=$("$CFG" help)
echo "$HELP_OUT" | grep -q -- "--project-slug" && ok "c8 help lists --project-slug" || bad "c8 help lists --project-slug"
echo "$HELP_OUT" | grep -q -- "-y, --yes" && ok "c8 help lists -y/--yes" || bad "c8 help lists -y/--yes"
"$CFG" setup --help >/dev/null 2>&1 && ok "c8 setup --help exits 0" || bad "c8 setup --help exits 0"

echo "=== C9: unknown setup option rejected ==="
(cd "$T" && "$CFG" setup --bogus x </dev/null) >/dev/null 2>&1
expect "c9 unknown option fails" test $? -ne 0

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
