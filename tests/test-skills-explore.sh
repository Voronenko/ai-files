#!/usr/bin/env bash
# Test suite for `ai-files-skills-explore` (unattended gilt-config generation).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPLORE="$REPO_ROOT/bin/ai-files-skills-explore"

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

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-explore-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

new_repo() { # new_repo <tag>
    FIX="$BASE/repo-$1"
    rm -rf "$FIX"; mkdir -p "$FIX"
    git -C "$FIX" init -q
    git -C "$FIX" symbolic-ref HEAD refs/heads/master
}
skill_md() { # <rel-dir|ROOT> <name> <desc> [internal]
    local d="$FIX/$1"; [ "$1" = "ROOT" ] && d="$FIX"
    mkdir -p "$d"
    if [ -n "${4:-}" ]; then
        printf -- '---\nname: %s\ndescription: %s\nmetadata:\n  internal: true\n---\nbody\n' "$2" "$3" > "$d/SKILL.md"
    else
        printf -- '---\nname: %s\ndescription: %s\n---\nbody\n' "$2" "$3" > "$d/SKILL.md"
    fi
}
agent_md() { # <rel-file>
    mkdir -p "$FIX/$(dirname "$1")"
    printf '# agent\n' > "$FIX/$1"
}
commit() {
    git -C "$FIX" add -A
    git -C "$FIX" -c user.email=t@example.com -c user.name=T commit -qm snapshot
}
run_explore() { # explore args... ; sets+exports OUT/RC for child asserts
    OUT=$(cd "$BASE" && "$EXPLORE" "$@" </dev/null 2>"$BASE/explore.err")
    RC=$?
    export OUT RC
}
yq_src() { # <dstDir> -> src value from $OUT
    yq ".repositories[0].sources[] | select(.dstDir == \"$1\") | .src" <<<"$OUT" 2>/dev/null
}
yq_count_src() { # <src> -> occurrences
    yq ".repositories[0].sources[].src" <<<"$OUT" 2>/dev/null | grep -cxF "$1"
}

echo "=== E1-E5: rich repository ==="
new_repo rich
skill_md ROOT root-tool "Root tool"
skill_md skills/alpha-tools "Alpha Tools" "Alpha description"
skill_md skills/.curated/hush-int "Hush Internal" "Internal only" internal
agent_md commands/Deploy-Helper.md
agent_md agents/night-run.md
commit

run_explore "file://$FIX"
expect "e1 exits 0 on local file:// source" test $RC -eq 0
expect "e1 output is valid yaml with repositories[0]" \
    bash -c "yq -e '.repositories[0].git' <<<\"\$OUT\" >/dev/null"
expect "e1 repo header carries source comment and giltDir" \
    bash -c "grep -q 'giltDir: ~/.gilt/clone' <<<\"\$OUT\" && grep -q 'ai-files skills explore' <<<\"\$OUT\""

OUT=$OUT expect_dummy=1 true # no-op keeps editor sane
expect "e2 root-level skill maps to src ." test "$(yq_src 'vendor/skills/root-tool')" = "."
expect "e2 root skill appears exactly once (dedupe)" test "$(yq_count_src '.')" -eq 1
expect "e3 skills/ skill mapped once (dedupe vs root scan)" \
    test "$(yq_count_src 'skills/alpha-tools')" -eq 1
export OUT
export OUT RC
expect "e3 internal skill filtered by default" \
    bash -c "! yq '.repositories[0].sources[].dstDir' <<<\"\$OUT\" | grep -q 'hush-int'"
expect "e4 agents sanitized to vendor/agents/<lower-hyphen>" \
    test "$(yq_src 'vendor/agents/deploy-helper')" = "commands/Deploy-Helper.md" -a "$(yq_src 'vendor/agents/night-run')" = "agents/night-run.md"
expect "e4 agents dir missing -> no agent entries crash" test "$RC" -eq 0
expect "e5 detected branch recorded as version" \
    bash -c "yq -e '.repositories[0].version == \"master\"' <<<\"\$OUT\" >/dev/null"
# normalize_url strips the file:// scheme, so the config carries the bare path:
expect "e5 non-github source passes through as local path" \
    bash -c "yq -e '.repositories[0].git == \"$FIX\"' <<<\"\$OUT\" >/dev/null"

echo "=== E6: INSTALL_INTERNAL_SKILLS=1 includes internal skills ==="
OUT=$(cd "$BASE" && INSTALL_INTERNAL_SKILLS=1 "$EXPLORE" "file://$FIX" </dev/null 2>/dev/null)
export OUT
expect "e6 internal skill included when env set (sanitized name)" \
    test "$(yq_src 'vendor/skills/hush-internal')" = "skills/.curated/hush-int"

echo "=== E7: bogus --branch falls back to default branch ==="
run_explore "file://$FIX" --branch does-not-exist
expect "e7 still succeeds via fallback clone" test $RC -eq 0
expect "e7 version is the actual branch (master)" \
    bash -c "yq -e '.repositories[0].version == \"master\"' <<<\"\$OUT\" >/dev/null"

echo "=== E8: --output writes file, stdout stays clean ==="
OUTFILE="$BASE/gilt-out.yaml"
# shellcheck disable=SC2034  # read back via bash -c below
STDOUT=$(cd "$BASE" && "$EXPLORE" "file://$FIX" --output "$OUTFILE" </dev/null 2>/dev/null)
RC=$?
expect "e8 rc0 and config written to file" \
    bash -c "test \$RC -eq 0 && yq -e '.repositories[0]' '$OUTFILE' >/dev/null"
expect "e8 stdout free of config body" \
    bash -c "! printf '%s' \"\$STDOUT\" | grep -q 'giltDir:'"

echo "=== E9: invalid source rejected ==="
run_explore "definitely not a source"
expect "e9 invalid source exits 1" test $RC -eq 1
grep -q "Invalid repository source" "$BASE/explore.err" \
    && ok "e9 error explains invalid source" || bad "e9 error explains invalid source"

echo "=== E10: github shorthand converts to ssh url in config ==="
new_repo ghshape
skill_md SKILL.md solo "Solo tool"
commit
# Hermetic shorthand test: git's insteadOf rewrites the would-be GitHub URL to
# a local mirror, while the explore output still shows the ssh-converted form.
GITCFG="$BASE/gitconfig"
printf '[url "file://%s"]\n\tinsteadOf = https://github.com/acme/ghshape\n' "$FIX" > "$GITCFG"
OUT=$(cd "$BASE" && GIT_CONFIG_GLOBAL="$GITCFG" "$EXPLORE" acme/ghshape </dev/null 2>/dev/null)
RC=$?
export OUT RC
expect "e10 exits 0 via rewritten mirror" test $RC -eq 0
expect "e10 shorthand explored, ssh form in config" \
    bash -c "yq -e '.repositories[0].git == \"git@github.com:acme/ghshape.git\"' <<<\"\$OUT\" >/dev/null"

echo "=== E11: repository without skills/agents exits 5 ==="
new_repo bare
printf 'readme\n' > "$FIX/README.md"
commit
run_explore "file://$FIX"
expect "e11 no content exits 5" test $RC -eq 5

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
