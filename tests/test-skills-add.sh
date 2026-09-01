#!/usr/bin/env bash
# Test suite for `ai-files-skills-add` (unattended list/install flows).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADD="$REPO_ROOT/bin/ai-files-skills-add"
LOCK="$REPO_ROOT/bin/ai-files-skills-lock"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in git yq python3; do
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

echo "=== A3: --all --yes installs real dirs into .ai-files/skills + lock ==="
new_work a3work
run_add "$SRC" --all --yes
expect "a3 exits 0 and reports install count" \
    bash -c "test \$RC -eq 0 && printf '%s' \"\$OUT\" | grep -q 'Installed 3 skill(s)'"
expect "a3 sanitized directory names present" \
    bash -c "test -d '$WORK/.ai-files/skills/alpha-tools' && test -d '$WORK/.ai-files/skills/beta-tools' && test -d '$WORK/.ai-files/skills/fancy-pkg'"
expect "a3 real directories (not symlinks) with SKILL.md" \
    bash -c "test ! -L '$WORK/.ai-files/skills/alpha-tools' && test -f '$WORK/.ai-files/skills/alpha-tools/SKILL.md'"
expect "a3 internal not installed" test ! -e "$WORK/.ai-files/skills/secret-internal"
expect "a3 skills-lock.json written with local source and skillPath" \
    python3 -c "import json,re;d=json.load(open('$WORK/skills-lock.json'));e=d['skills']['alpha-tools'];assert d['version']==1 and e['sourceType']=='local' and e['skillPath']=='skills/tools-alpha/SKILL.md' and re.fullmatch('[0-9a-f]{64}',e['computedHash'])"
expect "a3 no agent links when scripts live elsewhere" \
    bash -c "test ! -e '$WORK/.claude' && test ! -e '$WORK/.agents'"
grep -q "ai-files skill enable" "$BASE/add.err" && ok "a3 mismatch warning printed to stderr" \
    || bad "a3 mismatch warning printed to stderr"

echo "=== A4: rerun with -y skips existing without changes ==="
run_add "$SRC" --all --yes
expect "a4 exits 0 with skip notices" \
    bash -c "test \$RC -eq 0 && test \"\$(printf '%s' \"\$OUT\" | grep -c 'already installed')\" -ge 3"
expect "a4 directory set unchanged" \
    bash -c "[ \"\$(ls '$WORK/.ai-files/skills/' | sort)\" = \"\$(printf '%s\n' alpha-tools beta-tools fancy-pkg | sort)\" ]"

echo "=== A5: project mode always materializes real directories ==="
new_work a5copy
run_add "$SRC" --method copy --skill "Alpha Tools"
expect "a5 installs real directory with SKILL.md regardless of --method" \
    bash -c "test \$RC -eq 0 && test ! -L '$WORK/.ai-files/skills/alpha-tools' && test -f '$WORK/.ai-files/skills/alpha-tools/SKILL.md'"

echo "=== A6: repeatable --skill selects subset ==="
new_work a6sel
run_add "$SRC" --yes --skill "Alpha Tools" --skill "Fancy.Pkg!"
expect "a6 only requested skills installed" \
    bash -c "test \$RC -eq 0 && test -d '$WORK/.ai-files/skills/alpha-tools' && test -d '$WORK/.ai-files/skills/fancy-pkg' && test ! -e '$WORK/.ai-files/skills/beta-tools'"
expect "a6 lock holds only installed skills" \
    python3 -c "import json;d=json.load(open('$WORK/skills-lock.json'));assert sorted(d['skills'])==['alpha-tools','fancy-pkg']"

echo "=== A7: wildcard -s '*' equals --all ==="
new_work a7wild
run_add "$SRC" -y -s '*'
expect "a7 wildcard installs all three" \
    bash -c "test \$RC -eq 0 && test \$(ls '$WORK/.ai-files/skills/' | wc -l) -eq 3"

echo "=== A8: --global targets HOME and never writes a lock ==="
new_work a8glob
run_add "$SRC" --all --yes --global
expect "a8 installed under sandboxed HOME" \
    bash -c "test \$RC -eq 0 && test -d '$HOMEBOX/.claude/skills/alpha-tools' && test ! -e '$WORK/.ai-files'"
expect "a8 no skills-lock.json for global installs" test ! -e "$WORK/skills-lock.json"

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

echo "=== A12: project-local scripts link all four agent dirs ==="
P="$BASE/proj12"; rm -rf "$P"; mkdir -p "$P/bin"
cp "$REPO_ROOT/bin/ai-files-skills-add" "$REPO_ROOT/bin/ai-files-skill-enable" "$LOCK" "$P/bin/"
OUT=$(cd "$P" && HOME="$HOMEBOX" "$P/bin/ai-files-skills-add" "$SRC" --all --yes </dev/null 2>"$BASE/a12.err"); RC=$?
expect "a12 exits 0" test "$RC" -eq 0
expect "a12 linked in all four agent dirs" \
    bash -c "for a in claude kilo opencode agents; do test -L '$P'/.\$a/skills/alpha-tools || exit 1; done"
expect "a12 agent link resolves to .ai-files source" \
    bash -c "[ \"\$(readlink -f '$P/.agents/skills/alpha-tools')\" = '$P/.ai-files/skills/alpha-tools' ]"
expect "a12 lock entry present" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert 'alpha-tools' in d['skills']"

echo "=== A13: gh engine delegates fetch to gh skill install ==="
P="$BASE/proj13"; rm -rf "$P"; mkdir -p "$P/bin" "$P/fakebin"
cp "$REPO_ROOT/bin/ai-files-skills-add" "$REPO_ROOT/bin/ai-files-skill-enable" "$LOCK" "$P/bin/"
cat > "$P/fakebin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$GHCALLS"
if [[ "$1" == "skill" && "$2" == "install" ]]; then
    shift 2
    sel="$1"; shift
    dir=""
    while [[ $# -gt 0 ]]; do
        [[ "$1" == "--dir" ]] && dir="$2"
        shift
    done
    leaf="$(basename "$sel")"
    mkdir -p "$dir/$leaf"
    printf -- '---\nname: Alpha Tools\ndescription: gh-injected\n---\nbody\n' > "$dir/$leaf/SKILL.md"
fi
exit 0
GH
chmod +x "$P/fakebin/gh"
GHHOME="$BASE/ghhome"; mkdir -p "$GHHOME"
git config --file "$GHHOME/.gitconfig" url."$SRC".insteadOf "https://github.com/octo/widgets"
export GHCALLS="$BASE/gh-calls"; : > "$GHCALLS"
OUT=$(cd "$P" && HOME="$GHHOME" PATH="$P/fakebin:$PATH" AI_FILES_SKILLS_ENGINE=gh \
    "$P/bin/ai-files-skills-add" octo/widgets --skill "Alpha Tools" --yes </dev/null 2>"$BASE/a13.err"); RC=$?
expect "a13 exits 0" test "$RC" -eq 0
grep -q "skill install octo/widgets skills/tools-alpha --dir $P/.ai-files/skills/ --force" "$GHCALLS" \
    && ok "a13 gh received spec, path selector and --dir" \
    || bad "a13 gh received spec, path selector and --dir (got: $(cat "$GHCALLS"))"
expect "a13 gh-created dir renamed to sanitized name" test -f "$P/.ai-files/skills/alpha-tools/SKILL.md"
expect "a13 lock records github source" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['alpha-tools'];assert e['sourceType']=='github' and e['source']=='octo/widgets'"

echo "=== A14: gh install failure falls back to clone copy ==="
P="$BASE/proj14"; rm -rf "$P"; mkdir -p "$P/bin" "$P/badgh"
cp "$REPO_ROOT/bin/ai-files-skills-add" "$REPO_ROOT/bin/ai-files-skill-enable" "$LOCK" "$P/bin/"
cat > "$P/badgh/gh" <<'GH'
#!/usr/bin/env bash
# skills support detected (--help succeeds), but installs fail
[[ "$1 $2" == "skill install" && "$3" == "--help" ]] && exit 0
[[ "$1" == "skill" ]] && exit 1
exit 0
GH
chmod +x "$P/badgh/gh"
GHHOME="$BASE/ghhome2"; mkdir -p "$GHHOME"
git config --file "$GHHOME/.gitconfig" url."$SRC".insteadOf "https://github.com/octo/widgets"
OUT=$(cd "$P" && HOME="$GHHOME" PATH="$P/badgh:$PATH" env -u AI_FILES_SKILLS_ENGINE \
    "$P/bin/ai-files-skills-add" octo/widgets --skill "Alpha Tools" --yes </dev/null 2>"$BASE/a14.err"); RC=$?
export OUT RC
expect "a14 exits 0 despite gh failure" test "$RC" -eq 0
expect "a14 skill installed from clone after gh failure" test -f "$P/.ai-files/skills/alpha-tools/SKILL.md"
expect "a14 lock entry recorded" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['alpha-tools'];assert e['sourceType']=='github' and e['source']=='octo/widgets'"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
