#!/usr/bin/env bash
# Test suite for `ai-files-skills-sync` (agents.yaml → agent dot dirs).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-sync-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

# Project fixture: bin copies + skill sources + two of three agent dirs.
new_proj() { # new_proj <tag>
    P="$BASE/proj-$1"
    rm -rf "$P"
    mkdir -p "$P/bin" \
             "$P/.ai-files/skills/alpha" "$P/.ai-files/skills/beta" \
             "$P/.ai-files/skills/nested/gamma" \
             "$P/.ai-files/dotclaude/skills/delta" \
             "$P/.claude" "$P/.kilo"
    cp "$REPO_ROOT/bin/ai-files-skill-enable" "$P/bin/"
    cp "$REPO_ROOT/bin/ai-files-skills-sync"  "$P/bin/"
    for s in alpha beta nested/gamma; do
        printf -- '---\nname: placeholder\ndescription: stub\n---\n' > "$P/.ai-files/skills/$s/SKILL.md"
    done
    printf -- '---\nname: delta\ndescription: stub\n---\n' > "$P/.ai-files/dotclaude/skills/delta/SKILL.md"
    SYNC="$P/bin/ai-files-skills-sync"
}
write_yaml() {
    printf 'default_skills:\n' > "$P/agents.yaml"
    while IFS= read -r entry; do
        printf '  - %s\n' "$entry" >> "$P/agents.yaml"
    done
}
link() { # <agent> <leaf> -> resolved target or empty
    local l="$BASE/proj-$TAG/.$1/skills/$2"
    [ -L "$l" ] && readlink -f "$l" || true
}
run_sync() { # captures OUT/RC (stdout+stderr merged)
    TAG="${P##*-}"
    OUT=$(cd "$P" && "$SYNC" "$@" </dev/null 2>&1)
    RC=$?
    export OUT RC
}

echo "=== S1: --dry-run plans without touching the filesystem ==="
new_proj one
write_yaml <<'EOF'
alpha
beta
nested/gamma
delta
EOF
run_sync --dry-run
expect "s1 exits 0 in dry-run" test $RC -eq 0
expect "s1 prints planned links" bash -c "printf '%s' \"\$OUT\" | grep -q '+ alpha → .claude/skills/alpha'"
expect "s1 no symlinks created" test ! -e "$P/.claude/skills"

echo "=== S2: real run links present agents, skips absent opencode ==="
run_sync
expect "s2 exits 0 (all resolved)" test $RC -eq 0
expect "s2 claude links resolve to sources" \
    bash -c "[ \"\$(readlink -f '$P/.claude/skills/alpha')\" = '$P/.ai-files/skills/alpha' ] && [ \"\$(readlink -f '$P/.claude/skills/gamma')\" = '$P/.ai-files/skills/nested/gamma' ] && [ \"\$(readlink -f '$P/.claude/skills/delta')\" = '$P/.ai-files/dotclaude/skills/delta' ]"
expect "s2 kilo linked too" test -L "$P/.kilo/skills/beta"
expect "s2 opencode skipped with notice" bash -c "printf '%s' \"\$OUT\" | grep -q 'No .opencode/ directory'"
expect "s2 summary counts 8 links across 2 agents" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'Enabled: 8 skill(s) across 2 agent(s)'"

echo "=== S3: rerun is idempotent ==="
run_sync
expect "s3 exits 0" test $RC -eq 0
expect "s3 everything already enabled" \
    bash -c "test \"\$(printf '%s' \"\$OUT\" | grep -c 'already enabled')\" -ge 8"

echo "=== S4: missing and ambiguous skills produce partial failure ==="
new_proj four
mkdir -p "$P/.ai-files/skills/x1/dup" "$P/.ai-files/skills/x2/dup"
printf -- '---\nname: d1\ndescription: x\n---\n' > "$P/.ai-files/skills/x1/dup/SKILL.md"
printf -- '---\nname: d2\ndescription: x\n---\n' > "$P/.ai-files/skills/x2/dup/SKILL.md"
write_yaml <<'EOF'
ghost-skill
dup
EOF
run_sync
# nothing valid resolves -> hard error (exit 2) rather than partial success:
expect "s4 exits 2 when no skill resolves" test $RC -eq 2
expect "s4 warns about missing skill" bash -c "printf '%s' \"\$OUT\" | grep -q 'Skill not found: ghost-skill'"
expect "s4 warns about ambiguous leaf name" bash -c "printf '%s' \"\$OUT\" | grep -q 'Ambiguous name: dup'"
expect "s4 aborts with no-valid-skills error" bash -c "printf '%s' \"\$OUT\" | grep -q 'No valid skills to sync'"
expect "s4 nothing linked when nothing valid" test ! -e "$P/.claude/skills"

echo "=== S5: missing agents.yaml exits 2 with generated example ==="
new_proj five
run_sync
expect "s5 exits 2 when yaml missing" test $RC -eq 2
expect "s5 example yaml printed" bash -c "printf '%s' \"\$OUT\" | grep -q 'default_skills:'"

echo "=== S6: empty/comment-only list is a clean no-op ==="
new_proj six
printf '# default_skills:\n#   - nothing\n' > "$P/agents.yaml"
run_sync
expect "s6 exits 0 on empty list" test $RC -eq 0
expect "s6 explains empty list" bash -c "printf '%s' \"\$OUT\" | grep -q 'No skills listed'"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
