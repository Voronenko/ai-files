#!/usr/bin/env bash
# Test suite for `ai-files-update` (files / link-claude / link-kilo /
# link-opencode / link-specify) — unattended flows via a fixture dist.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE="$REPO_ROOT/bin/ai-files-update"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in git rsync; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-update-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

# ---------------------------------------------------------------- dist fixture
DIST="$BASE/dist"
mkdir -p "$DIST/.ai-files/skills/alpha-skill" \
         "$DIST/.ai-files/skills/vendor/tool" \
         "$DIST/.ai-files/skills/other/tool" \
         "$DIST/.ai-files/agents" "$DIST/.ai-files/rules" "$DIST/.ai-files/commands" \
         "$DIST/.ai-files/dotclaude/commands" \
         "$DIST/.ai-files/dotkilo" "$DIST/.ai-files/dotopencode" \
         "$DIST/.ai-files/dotspecify/templates" "$DIST/.ai-files/dotspecify/memory" \
         "$DIST/.opencode" "$DIST/.kilo"
printf 'VERSION=vtest\n'                     > "$DIST/.ai-files/VERSION"
printf -- '---\nname: alpha\ndescription: a\n---\nx\n' > "$DIST/.ai-files/skills/alpha-skill/SKILL.md"
printf -- '---\nname: tool\ndescription: t\n---\nx\n'  > "$DIST/.ai-files/skills/vendor/tool/SKILL.md"
printf -- '---\nname: tool2\ndescription: t\n---\nx\n' > "$DIST/.ai-files/skills/other/tool/SKILL.md"
printf 'helper\n' > "$DIST/.ai-files/agents/helper.md"
printf 'rule1\n'   > "$DIST/.ai-files/rules/r1.md"
printf 'cmd\n'     > "$DIST/.ai-files/commands/cmd1.md"
printf 'alpha\n'   > "$DIST/.ai-files/dotclaude/commands/alpha.md"
ln -s ../VERSION "$DIST/.ai-files/dotclaude/version-link"
printf 'k\n' > "$DIST/.ai-files/dotkilo/kfile"
printf 'o\n' > "$DIST/.ai-files/dotopencode/ofile"
printf 'opencode-dist\n' > "$DIST/.opencode/README.md"
printf 'kilo-dist\n'     > "$DIST/.kilo/README.md"
printf 'tpl\n'          > "$DIST/.ai-files/dotspecify/templates/tpl.md"
printf 'constitution\n' > "$DIST/.ai-files/dotspecify/memory/constitution.md"
printf '{}\n'           > "$DIST/.ai-files/dotspecify/config.json"

new_proj() { # <tag> [with-yaml] [extra-yaml-lines]
    P="$BASE/proj-$1"; export P
    rm -rf "$P"; mkdir -p "$P"
    git -C "$P" init -q
    if [ -n "${2:-}" ]; then
        { printf 'default_skills:\n  - alpha-skill\n';
          [ -n "${3:-}" ] && printf '  - %s\n' "$3"; } > "$P/default_skills.yaml"
    fi
}
# GIT_CONFIG_GLOBAL=/dev/null: the host's global excludesFile ignores
# .ai-files outright — fixtures must not inherit that.
run_upd() { OUT=$(cd "$P" && GIT_CONFIG_GLOBAL=/dev/null "$UPDATE" "$@" </dev/null 2>&1); RC=$?; export OUT RC; }
populate() { run_upd files -s "$DIST" -y; }
rl() { readlink -f "$1" 2>/dev/null; }   # resolved link target

echo "=== F1: files -s populates .ai-files from dist ==="
new_proj f1
populate
expect "f1 exits 0" test "$RC" -eq 0
expect "f1 VERSION copied" test "$(cat "$P/.ai-files/VERSION" 2>/dev/null)" = "VERSION=vtest"
expect "f1 skills present" \
    bash -c "test -f '$P/.ai-files/skills/alpha-skill/SKILL.md' && test -f '$P/.ai-files/skills/vendor/tool/SKILL.md'"
expect "f1 dotclaude nested symlink preserved" \
    test "$(rl "$P/.ai-files/dotclaude/version-link")" = "$P/.ai-files/VERSION"

echo "=== F2: dry-run leaves modified untracked file untouched ==="
new_proj f2
populate
printf 'changed\n' > "$P/.ai-files/VERSION"
run_upd files -s "$DIST" -d -y
expect "f2 exits 0" test "$RC" -eq 0
expect "f2 file kept" test "$(cat "$P/.ai-files/VERSION")" = "changed"
expect "f2 announces dry run" bash -c "printf '%s' \"\$OUT\" | grep -q 'DRY RUN'"

echo "=== F3: git-tracked modified file skipped even with -y ==="
new_proj f3
populate
GIT_CONFIG_GLOBAL=/dev/null git -C "$P" add -A
GIT_CONFIG_GLOBAL=/dev/null git -C "$P" -c user.email=t@t -c user.name=T commit -qm base
printf 'local-edit\n' > "$P/.ai-files/VERSION"
run_upd files -s "$DIST" -y
expect "f3 tracked file preserved" test "$(cat "$P/.ai-files/VERSION")" = "local-edit"
expect "f3 reports git-tracked skip" bash -c "printf '%s' \"\$OUT\" | grep -q 'Skipping git-tracked file: .ai-files/VERSION'"

echo "=== F4: untracked modified file overwritten with -y ==="
new_proj f4
populate
printf 'changed\n' > "$P/.ai-files/VERSION"
run_upd files -s "$DIST" -y
expect "f4 overwritten from dist" test "$(cat "$P/.ai-files/VERSION")" = "VERSION=vtest"

echo "=== F5: protected dirs and memory.db survive ==="
new_proj f5
populate
mkdir -p "$P/.ai-files/sessions" "$P/.ai-files/memory"
printf 'keep\n' > "$P/.ai-files/sessions/keep.md"
printf 'db\n'    > "$P/.ai-files/memory.db"
run_upd files -s "$DIST" -y
expect "f5 sessions file kept" test -f "$P/.ai-files/sessions/keep.md"
expect "f5 memory.db kept" test -f "$P/.ai-files/memory.db"

echo "=== F6: runtime artifacts untouched, never removal candidates ==="
new_proj f6
populate
mkdir -p "$P/.opencode/node_modules" "$P/.kilo/node_modules"
printf '{}' > "$P/.opencode/package.json"
printf 'j'   > "$P/.opencode/node_modules/x.js"
printf '{}' > "$P/.kilo/package.json"
run_upd files -s "$DIST" -y
expect "f6 runtime files kept" \
    bash -c "test -f '$P/.opencode/package.json' && test -f '$P/.opencode/node_modules/x.js' && test -f '$P/.kilo/package.json'"
expect "f6 node_modules not suggested for removal" \
    bash -c "! printf '%s' \"\$OUT\" | grep -q 'rm \".opencode/node_modules'"

echo "=== F7: target-only files become removal suggestions, kept on disk ==="
new_proj f7
populate
printf 'stale\n' > "$P/.ai-files/stale.txt"
run_upd files -s "$DIST" -y
expect "f7 suggestion printed" bash -c "printf '%s' \"\$OUT\" | grep -qF 'rm \".ai-files/stale.txt\"'"
expect "f7 stale file still on disk" test -f "$P/.ai-files/stale.txt"

echo "=== F8/F9: source handling ==="
new_proj f8
run_upd files -s "$BASE/no-such-dist" -y
expect "f8 missing source exits non-zero" test "$RC" -ne 0
run_upd files -s
expect "f9 --source without value rejected cleanly" test "$RC" -eq 1
expect "f9 usage error message" bash -c "printf '%s' \"\$OUT\" | grep -q 'requires a directory argument'"

echo "=== L: link-claude ==="
new_proj l1 with-yaml
populate
run_upd link-claude -y
expect "l1 exits 0" test "$RC" -eq 0
expect "l1 command file linked relatively" \
    bash -c "test \"\$(readlink -f '$P/.claude/commands/alpha.md')\" = '$P/.ai-files/dotclaude/commands/alpha.md' && case \"\$(readlink '$P/.claude/commands/alpha.md')\" in /*) false;; *) true;; esac"
expect "l1 nested symlink re-resolved" \
    test "$(rl "$P/.claude/version-link")" = "$P/.ai-files/VERSION"
expect "l1 default skill linked" \
    test "$(rl "$P/.claude/skills/alpha-skill")" = "$P/.ai-files/skills/alpha-skill"
expect "l1 vendored skills stay unlisted (not linked)" \
    bash -c "test ! -e '$P/.claude/skills/tool-vendor' && test ! -e '$P/.claude/skills/tool'"
expect "l1 agent linked" \
    test "$(rl "$P/.claude/agents/helper.md")" = "$P/.ai-files/agents/helper.md"

echo "=== L-collision: vendored name clash gets namespace suffix ==="
new_proj l2
printf 'default_skills:\n  - alpha-skill\n  - vendor/tool\n  - other/tool\n' > "$P/default_skills.yaml"
populate
run_upd link-claude -y
expect "l2 colliding vendor entry suffixed" \
    test "$(rl "$P/.claude/skills/tool-vendor")" = "$P/.ai-files/skills/vendor/tool"
expect "l2 second colliding entry suffixed too" \
    test "$(rl "$P/.claude/skills/tool-other")" = "$P/.ai-files/skills/other/tool"

echo "=== L3: rerun idempotent + stray flagged ==="
printf 'stray\n' > "$P/.claude/stray.md"
run_upd link-claude -y
expect "l3 rerun exits 0" test "$RC" -eq 0
expect "l3 stray flagged, kept" \
    bash -c "printf '%s' \"\$OUT\" | grep -qF 'rm \".claude/stray.md\"' && test -f '$P/.claude/stray.md'"

echo "=== L4: dry-run creates nothing ==="
new_proj l4 with-yaml
populate
run_upd link-claude -d -y
expect "l4 .claude not created" test ! -e "$P/.claude"
expect "l4 preview announced" bash -c "printf '%s' \"\$OUT\" | grep -q 'Would create directory: .claude'"

echo "=== K: link-kilo ==="
new_proj k1 with-yaml
populate
run_upd link-kilo -y
expect "k1 exits 0" test "$RC" -eq 0
expect "k1 dotkilo file linked" \
    test "$(rl "$P/.kilo/kfile")" = "$P/.ai-files/dotkilo/kfile"
expect "k1 rules linked" \
    test "$(rl "$P/.kilo/rules/r1.md")" = "$P/.ai-files/rules/r1.md"
expect "k1 default skill linked" \
    test "$(rl "$P/.kilo/skills/alpha-skill")" = "$P/.ai-files/skills/alpha-skill"

echo "=== K2: .kilo/skills as symlink skips individual linking ==="
new_proj k2 with-yaml
populate
ln -s /tmp/nowhere-kilo "$P/.kilo/skills"
run_upd link-kilo -y
expect "k2 skills dir left as symlink" \
    test "$(readlink "$P/.kilo/skills")" = "/tmp/nowhere-kilo"

echo "=== K3: node_modules symlink leftovers warned, kept ==="
new_proj k3 with-yaml
populate
mkdir -p "$P/.kilo/node_modules"
ln -s "$P/.ai-files/VERSION" "$P/.kilo/node_modules/pkg"
run_upd link-kilo -y
expect "k3 warning printed" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'node_modules contains symlinks'"
expect "k3 leftover symlink kept" test "$(rl "$P/.kilo/node_modules/pkg")" = "$P/.ai-files/VERSION"

echo "=== O: link-opencode ==="
new_proj o1 with-yaml
populate
run_upd link-opencode -y
expect "o1 exits 0" test "$RC" -eq 0
expect "o1 dotopencode file linked" \
    test "$(rl "$P/.opencode/ofile")" = "$P/.ai-files/dotopencode/ofile"
expect "o1 commands linked from .ai-files/commands" \
    test "$(rl "$P/.opencode/commands/cmd1.md")" = "$P/.ai-files/commands/cmd1.md"
expect "o1 rules linked" \
    test "$(rl "$P/.opencode/rules/r1.md")" = "$P/.ai-files/rules/r1.md"
expect "o1 default skill linked" \
    test "$(rl "$P/.opencode/skills/alpha-skill")" = "$P/.ai-files/skills/alpha-skill"

echo "=== O2: runtime artifacts skipped in candidate scan ==="
mkdir -p "$P/.opencode/node_modules"
printf '{}' > "$P/.opencode/package.json"
printf 'j' > "$P/.opencode/node_modules/x.js"
run_upd link-opencode -y
expect "o2 runtime files kept and unflagged" \
    bash -c "test -f '$P/.opencode/package.json' && ! printf '%s' \"\$OUT\" | grep -q 'rm \".opencode/package.json\"'"

echo "=== S: link-specify ==="
new_proj s1
populate
run_upd link-specify -y
expect "s1 exits 0" test "$RC" -eq 0
expect "s1 .specify is a real directory" bash -c "test -d '$P/.specify' && test ! -L '$P/.specify'"
expect "s1 shared children linked" \
    bash -c "test \"\$(readlink -f '$P/.specify/templates')\" = '$P/.ai-files/dotspecify/templates' && test \"\$(readlink -f '$P/.specify/config.json')\" = '$P/.ai-files/dotspecify/config.json'"
expect "s1 memory copied locally once" \
    bash -c "test -f '$P/.specify/memory/constitution.md' && test ! -L '$P/.specify/memory'"

echo "=== S2: local memory edits survive reruns ==="
printf 'edited\n' > "$P/.specify/memory/constitution.md"
run_upd link-specify -y
expect "s2 local edit kept" test "$(cat "$P/.specify/memory/constitution.md")" = "edited"

echo "=== S3: legacy .specify symlink migrated under -y ==="
new_proj s3
populate
ln -s .ai-files/dotspecify "$P/.specify"
run_upd link-specify -y
expect "s3 replaced by real dir with linked children" \
    bash -c "test -d '$P/.specify' && test ! -L '$P/.specify' && test \"\$(readlink -f '$P/.specify/templates')\" = '$P/.ai-files/dotspecify/templates'"

echo "=== S4: dry-run creates nothing ==="
new_proj s4
populate
run_upd link-specify -d -y
expect "s4 .specify not created" test ! -e "$P/.specify"

echo "=== D: dispatch ==="
new_proj d1 with-yaml
populate
run_upd -y link-claude
expect "d1 global opts before subcommand honored" \
    bash -c "test \"\$(readlink -f '$P/.claude/commands/alpha.md')\" = '$P/.ai-files/dotclaude/commands/alpha.md'"
run_upd bogus-sub
expect "d2 unknown subcommand rejected" test "$RC" -eq 1
run_upd help
expect "d3 help exits 0" test "$RC" -eq 0

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
