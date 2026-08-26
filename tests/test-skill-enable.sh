#!/usr/bin/env bash
# Test suite for `ai-files-skill-enable` (unattended symlink linking).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENABLE_SRC="$REPO_ROOT/bin/ai-files-skill-enable"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-enable-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

new_proj() { # new_proj <tag> — minimal: only .claude exists
    P="$BASE/proj-$1"
    rm -rf "$P"; mkdir -p "$P/bin" "$P/.claude" \
        "$P/.ai-files/skills/top1" "$P/.ai-files/skills/group/nested" \
        "$P/.ai-files/skills/l1/dupl" "$P/.ai-files/skills/l2/dupl" \
        "$P/.ai-files/dotclaude/skills/dc-skill"
    cp "$ENABLE_SRC" "$P/bin/"
    for s in top1 group/nested l1/dupl l2/dupl; do
        printf -- '---\nname: x\ndescription: x\n---\n' > "$P/.ai-files/skills/$s/SKILL.md"
    done
    printf -- '---\nname: dc\ndescription: x\n---\n' > "$P/.ai-files/dotclaude/skills/dc-skill/SKILL.md"
}
resolved() { # <agent> <leaf> -> readlink -f of link or empty
    local l="$P/.$1/skills/$2"
    [ -L "$l" ] && readlink -f "$l" || true
}
run_en() { OUT=$(cd "$P" && "$P/bin/ai-files-skill-enable" "$@" </dev/null 2>&1); RC=$?; export OUT RC; }

echo "=== N1: default links into all four agent dirs ==="
new_proj one
run_en top1
expect "n1 exits 0" test $RC -eq 0
for a in claude kilo opencode agents; do
    expect "n1 linked for $a with resolved source" \
        bash -c "[ \"\$(readlink -f '$P/.$a/skills/top1')\" = '$P/.ai-files/skills/top1' ]"
done
expect "n1 symlinks are relative, not absolute" \
    bash -c "[ -n \"\$(readlink '$P/.claude/skills/top1')\" ] && [ \"\$(readlink '$P/.claude/skills/top1' | head -c1)\" != '/' ]"

echo "=== N2: --kilo-only touches exactly kilo ==="
new_proj two
run_en top1 --kilo-only
expect "n2 exits 0" test $RC -eq 0
expect "n2 kilo link created" test -L "$P/.kilo/skills/top1"
expect "n2 other agent dirs untouched" \
    bash -c "test ! -e '$P/.claude/skills/top1' && test ! -e '$P/.opencode' && test ! -e '$P/.agents'"

echo "=== N3: scoped flags are mutually exclusive ==="
new_proj three
run_en top1 --claude-only --kilo-only
expect "n3 exits non-zero" test $RC -ne 0

echo "=== N4: rerun reports Already enabled without churn ==="
run_en top1                       # first link already created by N1 flow above
BEFORE_LINK="$(readlink "$P/.claude/skills/top1")"
run_en top1                       # second run must be a no-op
expect "n4 exits 0" test $RC -eq 0
expect "n4 already-enabled notice present" \
    bash -c "printf '%s' \"\$OUT\" | grep -qc 'Already enabled'"
expect "n4 link target unchanged" test "$(readlink "$P/.claude/skills/top1")" = "$BEFORE_LINK"

echo "=== N5: wrong-target symlink is replaced ==="
new_proj five
mkdir -p "$P/.claude/skills" "$P/.other"
ln -s "$P/.other" "$P/.claude/skills/top1"
run_en top1
expect "n5 replaced and resolves to source" \
    bash -c "[ \"\$(readlink -f '$P/.claude/skills/top1')\" = '$P/.ai-files/skills/top1' ]"
echo "$OUT" | grep -q "Replacing:" && ok "n5 replacement announced" || bad "n5 replacement announced"

echo "=== N6: real directory occupying target path refused ==="
new_proj six
mkdir -p "$P/.claude/skills/top1"
run_en top1
expect "n6 exits 3 on non-symlink conflict" test $RC -eq 3
grep -q "not a symlink" <<<"$OUT" && ok "n6 conflict explained" || bad "n6 conflict explained"

echo "=== N7: broken symlink repaired ==="
new_proj seven
mkdir -p "$P/.claude/skills"
ln -s "$P/nowhere" "$P/.claude/skills/top1"
run_en top1
expect "n7 repaired to correct source" \
    bash -c "[ \"\$(readlink -f '$P/.claude/skills/top1')\" = '$P/.ai-files/skills/top1' ]"

echo "=== N8: unknown skill lists available and exits 1 ==="
new_proj eight
run_en does-not-exist
expect "n8 exits 1" test $RC -eq 1
expect "n8 available list includes top1" bash -c "printf '%s' \"\$OUT\" | grep -q -- '- top1'"

echo "=== N9: ambiguous leaf name aborts with candidates ==="
new_proj nine
run_en dupl
expect "n9 exits 1 on ambiguity" test $RC -ne 0
expect "n9 multiple-match message shown" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'Multiple matches'"

echo "=== N10: dotclaude source + nested qualified path ==="
new_proj ten
run_en dc-skill --agents-only
expect "n10 dotclaude skill resolved" \
    bash -c "[ \"\$(readlink -f '$P/.agents/skills/dc-skill')\" = '$P/.ai-files/dotclaude/skills/dc-skill' ]"
run_en group/nested --claude-only
expect "n10 nested qualified path resolved" \
    bash -c "[ \"\$(readlink -f '$P/.claude/skills/nested')\" = '$P/.ai-files/skills/group/nested' ]"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
