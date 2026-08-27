#!/usr/bin/env bash
# Test suite for `ai-files-skills-add` (unattended list/install flows).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADD="$REPO_ROOT/bin/ai-files-skills-add"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in git yq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-add-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

if ! command -v fzf >/dev/null 2>&1; then
    mkdir -p "$BASE/fakebin"
    printf '#!/bin/sh\nexit 0\n' > "$BASE/fakebin/fzf"
    chmod +x "$BASE/fakebin/fzf"
    export PATH="$BASE/fakebin:$PATH"
fi

FIX="$BASE/repo"
mkdir -p "$FIX"
git -C "$FIX" init -q

skill_md() { # <rel-dir> <name> <desc> [internal]
    local d="$FIX/$1"; mkdir -p "$d"
    if [ -n "${4:-}" ]; then
        printf -- '---\nname: %s\ndescription: %s\nmetadata:\n  internal: true\n---\nbody\n' "$2" "$3" > "$d/SKILL.md"
    else
        printf -- '---\nname: %s\ndescription: %s\n---\nbody\n' "$2" "$3" > "$d/SKILL.md"
    fi
}
commit() {
    git -C "$FIX" add -A
    git -C "$FIX" -c user.email=t@example.com -c user.name=T commit -qm snapshot
}

skill_md skills/tools-alpha "Alpha Tools" "Alpha desc"
skill_md skills/beta-tools "Beta Tools" "Beta desc"
skill_md skills/fancy "Fancy.Pkg!" "Fancy package"
skill_md skills/secret-internal "Secret Internal" "Hidden" internal
commit

SRC="file://$FIX"          # hermetic source (F1)
HOMEBOX="$BASE/home"       # sandboxed HOME for ~/.cache/skills + --global
mkdir -p "$HOMEBOX"
export HOMEBOX
WORK="$BASE/work-default"   # default install cwd until a test overrides it
mkdir -p "$WORK"

run_add() { # cwd is caller's WORK; captures stdout in OUT, rc in RC
    OUT=$(cd "$WORK" && HOME="$HOMEBOX" "$ADD" "$@" </dev/null 2>"$BASE/add.err")
    RC=$?
    export OUT RC WORK
}
new_work() { local w="$BASE/$1"; rm -rf "$w"; mkdir -p "$w"; WORK="$w"; export WORK; }

echo "=== A1: --list hides internal, shows raw names ==="
run_add "$SRC" --list
expect "a1 exits 0" test $RC -eq 0
expect "a1 lists alpha/beta/fancy by frontmatter name" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'Alpha Tools' && printf '%s' \"\$OUT\" | grep -q 'Fancy.Pkg!' && printf '%s' \"\$OUT\" | grep -q 'Beta Tools'"
export OUT
expect "a1 internal skill hidden by default" \
    bash -c "! printf '%s' \"\$OUT\" | grep -q 'Secret Internal'"

echo "=== A2: INSTALL_INTERNAL_SKILLS reveals internals in list ==="
OUT=$(HOME="$HOMEBOX" INSTALL_INTERNAL_SKILLS=1 "$ADD" "$SRC" --list </dev/null 2>/dev/null)
export OUT
expect "a2 internal listed when env set" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'Secret Internal'"

echo "=== A3: --all --yes installs sanitized symlinks into project dir ==="
new_work a3work
run_add "$SRC" --all --yes
expect "a3 exits 0 and reports install count" \
    bash -c "test \$RC -eq 0 && printf '%s' \"\$OUT\" | grep -q 'Installed 3 skill(s)'"
expect "a3 sanitized directory names present" \
    bash -c "test -d '$WORK/.claude/skills/alpha-tools' && test -d '$WORK/.claude/skills/beta-tools' && test -d '$WORK/.claude/skills/fancy-pkg'"
expect "a3 internal not installed" test ! -e "$WORK/.claude/skills/secret-internal"
expect "a3 symlink method points into canonical cache" \
    bash -c "test -L '$WORK/.claude/skills/alpha-tools' && [ \"\$(readlink -f '$WORK/.claude/skills/alpha-tools')\" = \"\$HOMEBOX/.cache/skills/alpha-tools\" ]"

echo "=== A4: rerun with -y skips existing without changes ==="
run_add "$SRC" --all --yes
expect "a4 exits 0 with skip notices" \
    bash -c "test \$RC -eq 0 && test \"\$(printf '%s' \"\$OUT\" | grep -c 'already installed')\" -ge 3"
expect "a4 directory set unchanged" \
    bash -c "[ \"\$(ls '$WORK/.claude/skills/' | sort)\" = \"\$(printf '%s\n' alpha-tools beta-tools fancy-pkg | sort)\" ]"

echo "=== A5: --method copy materializes real directories ==="
new_work a5copy
run_add "$SRC" --method copy --skill "Alpha Tools"
expect "a5 copy installs real directory with SKILL.md" \
    bash -c "test \$RC -eq 0 && test ! -L '$WORK/.claude/skills/alpha-tools' && test -f '$WORK/.claude/skills/alpha-tools/SKILL.md'"

echo "=== A6: repeatable --skill selects subset ==="
new_work a6sel
run_add "$SRC" --yes --skill "Alpha Tools" --skill "Fancy.Pkg!"
expect "a6 only requested skills installed" \
    bash -c "test \$RC -eq 0 && test -d '$WORK/.claude/skills/alpha-tools' && test -d '$WORK/.claude/skills/fancy-pkg' && test ! -e '$WORK/.claude/skills/beta-tools'"

echo "=== A7: wildcard -s '*' equals --all ==="
new_work a7wild
run_add "$SRC" -y -s '*'
expect "a7 wildcard installs all three" \
    bash -c "test \$RC -eq 0 && test \$(ls '$WORK/.claude/skills/' | wc -l) -eq 3"

echo "=== A8: --global targets HOME ==="
new_work a8glob
run_add "$SRC" --all --yes --global
expect "a8 installed under sandboxed HOME" \
    bash -c "test \$RC -eq 0 && test -d '$HOMEBOX/.claude/skills/alpha-tools' && test ! -e '$WORK/.claude'"

echo "=== A9: unknown skill exits 5 with table on stderr ==="
run_add "$SRC" --yes --skill nope-missing
expect "a9 unknown skill rc5" test $RC -eq 5
grep -q "SKILL" "$BASE/add.err" && ok "a9 available skills table printed to stderr" \
    || bad "a9 available skills table printed to stderr"

echo "=== A10: option validation ==="
run_add "$SRC" --all --skill "Alpha Tools"
expect "a10 --all + --skill mutually exclusive" test $RC -eq 2
run_add "$SRC" --method rsync
expect "a10 invalid method rejected" test $RC -eq 2
run_add "no slashes here"
expect "a10 invalid source rejected (rc1)" test $RC -eq 1

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
