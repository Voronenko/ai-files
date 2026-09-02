#!/usr/bin/env bash
# Test suite for `ai-files-skills-remove`.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOVE="$REPO_ROOT/bin/ai-files-skills-remove"
LOCK="$REPO_ROOT/bin/ai-files-skills-lock"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in python3; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-remove-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

new_proj() {
    local p="$BASE/$1"
    rm -rf "$p"
    mkdir -p "$p/bin" "$p/.ai-files/skills/doomed"
    cp "$REMOVE" "$LOCK" "$REPO_ROOT/bin/ai-files-skill-enable" \
       "$REPO_ROOT/bin/ai-files-skill-disable" "$p/bin/"
    printf -- '---\nname: doomed\ndescription: d\n---\nbody\n' > "$p/.ai-files/skills/doomed/SKILL.md"
    echo "$p"
}

run_remove() { # <proj> <name> [args...]
    local p="$1" n="$2"; shift 2
    OUT=$(cd "$p" && "$p/bin/ai-files-skills-remove" "$n" "$@" </dev/null 2>"$BASE/r.err")
    RC=$?
    export OUT RC
}

echo "=== R1: full removal (links, dir, lock entry) ==="
P=$(new_proj r1)
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" add doomed --source octo/widgets --skill-path skills/doomed/SKILL.md --hash deadbeef >/dev/null 2>&1
"$P/bin/ai-files-skill-enable" doomed >/dev/null 2>&1
run_remove "$P" doomed
expect "r1 exits 0" test "$RC" -eq 0
expect "r1 links gone in all four agent dirs" \
    bash -c "for a in claude kilo opencode agents; do test ! -e '$P'/.\$a/skills/doomed || exit 1; done"
expect "r1 skill directory deleted" test ! -e "$P/.ai-files/skills/doomed"
expect "r1 lock entry dropped" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert 'doomed' not in d['skills']"

echo "=== R2: nothing to remove exits 1 ==="
P=$(new_proj r2)
rm -rf "$P/.ai-files/skills/doomed"
run_remove "$P" ghost
expect "r2 exits 1 when neither dir nor entry exists" test "$RC" -eq 1

echo "=== R3: lock-only entry is cleaned ==="
P=$(new_proj r3)
rm -rf "$P/.ai-files/skills/doomed"
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" add doomed --source octo/widgets --hash deadbeef >/dev/null 2>&1
run_remove "$P" doomed
expect "r3 exits 0" test "$RC" -eq 0
expect "r3 lock entry dropped" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert 'doomed' not in d['skills']"

echo "=== R5: raw-key skill removed by raw name (dir is sanitized) ==="
P="$BASE/r5"; rm -rf "$P"; mkdir -p "$P/bin" "$P/.ai-files/skills/fancy.pkg"
cp "$REMOVE" "$LOCK" "$REPO_ROOT/bin/ai-files-skill-enable" \
   "$REPO_ROOT/bin/ai-files-skill-disable" "$P/bin/"
printf -- '---\nname: Fancy.Pkg!\ndescription: d\n---\nbody\n' > "$P/.ai-files/skills/fancy.pkg/SKILL.md"
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" \
    add "Fancy.Pkg!" --source octo/widgets --hash deadbeef >/dev/null 2>&1
"$P/bin/ai-files-skill-enable" fancy.pkg >/dev/null 2>&1
OUT=$(cd "$P" && "$P/bin/ai-files-skills-remove" "Fancy.Pkg!" </dev/null 2>"$BASE/r5.err"); RC=$?
expect "r5 exits 0 removing by raw name" test "$RC" -eq 0
expect "r5 sanitized dir and links gone" \
    bash -c "test ! -e '$P/.ai-files/skills/fancy.pkg' && test ! -e '$P/.agents/skills/fancy.pkg'"
expect "r5 raw lock key dropped" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert 'Fancy.Pkg!' not in d['skills']"

echo "=== R6: removal by sanitized dir name resolves the raw key ==="
P="$BASE/r6"; rm -rf "$P"; mkdir -p "$P/bin" "$P/.ai-files/skills/fancy.pkg"
cp "$REMOVE" "$LOCK" "$REPO_ROOT/bin/ai-files-skill-enable" \
   "$REPO_ROOT/bin/ai-files-skill-disable" "$P/bin/"
printf -- '---\nname: Fancy.Pkg!\ndescription: d\n---\nbody\n' > "$P/.ai-files/skills/fancy.pkg/SKILL.md"
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" \
    add "Fancy.Pkg!" --source octo/widgets --hash deadbeef >/dev/null 2>&1
OUT=$(cd "$P" && "$P/bin/ai-files-skills-remove" "fancy.pkg" </dev/null 2>"$BASE/r6.err"); RC=$?
expect "r6 exits 0 removing by dir name" test "$RC" -eq 0
expect "r6 raw lock key dropped via dir-name resolution" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert 'Fancy.Pkg!' not in d['skills']"

echo "=== R4: path traversal names rejected ==="
P=$(new_proj r4)
run_remove "$P" "../evil"
expect "r4 traversal name exits 2" test "$RC" -eq 2
expect "r4 no lock file harmed" test ! -e "$P/evil"
run_remove "$P" "/etc"
expect "r4 absolute name exits 2" test "$RC" -eq 2

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
