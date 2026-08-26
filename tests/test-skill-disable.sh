#!/usr/bin/env bash
# Test suite for `ai-files-skill-disable` (unattended symlink removal).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-disable-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

new_proj() { # proj with sources + all four agent dirs + enable copy
    P="$BASE/proj-$1"
    rm -rf "$P"; mkdir -p "$P/bin" "$P/.claude/skills" "$P/.kilo/skills" \
        "$P/.opencode/skills" "$P/.agents/skills" \
        "$P/.ai-files/skills/top1" "$P/.ai-files/skills/beta" \
        "$P/.ai-files/skills/group/nested"
    cp "$REPO_ROOT/bin/ai-files-skill-enable"  "$P/bin/"
    cp "$REPO_ROOT/bin/ai-files-skill-disable" "$P/bin/"
    for s in top1 beta group/nested; do
        printf -- '---\nname: x\ndescription: x\n---\n' > "$P/.ai-files/skills/$s/SKILL.md"
    done
    # establish links via the real enable tool
    for s in top1 beta group/nested; do
        (cd "$P" && "$P/bin/ai-files-skill-enable" "$s" >/dev/null 2>&1)
    done
}
DIS() { local d="$P/bin/ai-files-skill-disable"; OUT=$(cd "$P" && "$d" "$@" </dev/null 2>&1); RC=$?; export OUT RC; }
linked() { [ -L "$P/.$1/skills/$2" ]; }

echo "=== D1: default removes matching links everywhere ==="
new_proj one
DIS top1
expect "d1 exits 0" test $RC -eq 0
expect "d1 top1 removed from all four agents" \
    bash -c "for a in claude kilo opencode agents; do test ! -e '$P/.'\$a'/skills/top1' || exit 1; done"
expect "d1 unrelated skill (beta) links preserved" \
    bash -c "linked() { [ -L \"$P/.\$1/skills/\$2\" ]; }; linked claude beta && linked agents beta"
echo "$OUT" | grep -q "Skill disabled successfully" \
    && ok "d1 success banner shown" || bad "d1 success banner shown"

echo "=== D2: scoped --agents-only touches only .agents ==="
new_proj two
DIS top1 --agents-only
expect "d2 exits 0" test $RC -eq 0
expect "d2 .agents link gone, others intact" \
    bash -c "test ! -e '$P/.agents/skills/top1' && linked() { [ -L \"$P/.\$1/skills/top1\" ]; }; linked claude top1 && linked kilo top1"

echo "=== D3: disabling an unlinked skill is a clean no-op ==="
DIS top1 --agents-only
expect "d3 exits 0 when nothing linked" test $RC -eq 0
echo "$OUT" | grep -q "not linked" && ok "d3 not-linked notice shown" || bad "d3 not-linked notice shown"

echo "=== D4: unknown skill exits 1 ==="
new_proj four
DIS ghost-skill
expect "d4 exits 1" test $RC -eq 1

echo "=== D5: foreign symlinks are never removed ==="
new_proj five
ln -sfn /tmp/definitely-elsewhere "$P/.claude/skills/top1"   # wrong target (forced over the real link)
mkdir -p "$P/vendor-keep"
ln -s "$P/vendor-keep" "$P/.claude/skills/beta"            # right name, wrong target
DIS top1 >/dev/null 2>&1
expect "d5 wrong-target top1 link untouched" test -L "$P/.claude/skills/top1"
expect "d5 same-name foreign link untouched" test -L "$P/.claude/skills/beta"
expect "d5 exit code still 0 with notices" test $RC -eq 0

echo "=== D6: qualified path disables nested skill ==="
new_proj six
expect "d6 precondition: nested linked" linked claude nested
DIS group/nested
expect "d6 exits 0" test $RC -eq 0
expect "d6 nested link removed everywhere" \
    bash -c "for a in claude kilo opencode agents; do test ! -e '$P/.'\$a'/skills/nested' || exit 1; done"
expect "d6 sibling top1 unaffected" linked claude top1

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
