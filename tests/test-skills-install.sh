#!/usr/bin/env bash
# Test suite for `ai-files-skills-install` (lock-driven restore).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$REPO_ROOT/bin/ai-files-skills-install"
LOCK="$REPO_ROOT/bin/ai-files-skills-lock"
ENABLE="$REPO_ROOT/bin/ai-files-skill-enable"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in git python3; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-install-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

export AI_FILES_SKILLS_ENGINE=git   # hermetic: never touch the gh path here

#--- fixture source repo with two skills -------------------------------
FIX="$BASE/repo"
mkdir -p "$FIX"
git -C "$FIX" init -q

skill_md() { # <rel-dir> <name> <desc>
    local d="$FIX/$1"; mkdir -p "$d"
    printf -- '---\nname: %s\ndescription: %s\n---\nbody\n' "$2" "$3" > "$d/SKILL.md"
}
commit() {
    git -C "$FIX" add -A
    git -C "$FIX" -c user.email=t@example.com -c user.name=T commit -qm snapshot
}

skill_md skills/alpha "Alpha Tools" "Alpha desc"
skill_md skills/beta "Beta Tools" "Beta desc"
# true repo-root skill: SKILL.md at the clone root
printf -- '---\nname: Root Skill\ndescription: Lives at repo root\n---\nbody\n' > "$FIX/SKILL.md"
commit

SRC="file://$FIX"

# Sandbox HOME whose gitconfig rewrites the fake github spec to the local
# fixture, so lock entries classify as "github" and clones stay hermetic.
HOMEBOX="$BASE/home"
mkdir -p "$HOMEBOX"
git config --file "$HOMEBOX/.gitconfig" url."$SRC".insteadOf "https://github.com/octo/widgets"

#--- new_proj: fake project with local copies of the scripts ------------
new_proj() {
    local p="$BASE/$1"
    rm -rf "$p"
    mkdir -p "$p/bin" "$p/.ai-files/skills"
    cp "$INSTALL" "$LOCK" "$ENABLE" "$REPO_ROOT/bin/ai-files-skill-disable" "$p/bin/"
    echo "$p"
}

seed_lock() { # <proj> <name> <rel-dir>
    "$LOCK" --dir "$1" --skills-dir "$1/.ai-files/skills" \
        add "$2" --source octo/widgets --skill-path "${3:+$3/}SKILL.md" --hash deadbeefcafe0123 >/dev/null 2>&1
}

run_install() { # <proj> [args...] — captures OUT/RC
    local p="$1"; shift
    OUT=$(cd "$p" && HOME="$HOMEBOX" "$p/bin/ai-files-skills-install" "$@" </dev/null 2>"$BASE/i.err")
    RC=$?
    export OUT RC
}

echo "=== I1: missing lock exits 0 with notice ==="
P=$(new_proj i1)
run_install "$P"
expect "i1 exits 0" test "$RC" -eq 0
expect "i1 reports nothing to install" bash -c "printf '%s' \"\$OUT\" | grep -q 'No skills to install'"

echo "=== I2: installs missing skills, links agents, re-stamps lock ==="
P=$(new_proj i2)
seed_lock "$P" alpha skills/alpha
seed_lock "$P" beta skills/beta
run_install "$P"
expect "i2 exits 0" test "$RC" -eq 0
expect "i2 skill dirs created" \
    bash -c "test -f '$P/.ai-files/skills/alpha/SKILL.md' && test -f '$P/.ai-files/skills/beta/SKILL.md'"
expect "i2 linked in all four agent dirs" \
    bash -c "for a in claude kilo opencode agents; do test -L '$P'/.\$a/skills/alpha || exit 1; done"
expect "i2 lock hash re-stamped from real content" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['alpha'];import re;assert re.fullmatch('[0-9a-f]{64}',e['computedHash']) and e['computedHash']!='deadbeefcafe0123'"

echo "=== I3: rerun is a no-op ==="
cp "$P/skills-lock.json" "$BASE/i2-lock.json"
run_install "$P"
expect "i3 exits 0 with nothing to do" \
    bash -c "test \$RC -eq 0 && printf '%s' \"\$OUT\" | grep -q 'No skills to install'"
expect "i3 lock unchanged" cmp -s "$BASE/i2-lock.json" "$P/skills-lock.json"

echo "=== I4: tampered dir warns; --force reinstalls and restores hash ==="
echo "tampered" >> "$P/.ai-files/skills/alpha/SKILL.md"
run_install "$P"
expect "i4 drift skipped without --force" \
    bash -c "test \$RC -eq 0 && grep -q 'hash differs from lock' '$BASE/i.err'"
run_install "$P" --force
expect "i4 --force reinstalls drifted skill" \
    bash -c "test \$RC -eq 0 && ! grep -q '^tampered' '$P/.ai-files/skills/alpha/SKILL.md'"
expect "i4 lock hash equals pristine re-stamp" \
    python3 -c "
import json,subprocess
e=json.load(open('$P/skills-lock.json'))['skills']['alpha']
h=subprocess.run(['$LOCK','hash','$P/.ai-files/skills/alpha'],capture_output=True,text=True).stdout.strip()
assert e['computedHash']==h"

echo "=== I5: local entries are skipped with a notice ==="
P=$(new_proj i5)
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" \
    add localthing --source "$BASE/repo" --hash deadbeef >/dev/null 2>&1
run_install "$P"
expect "i5 exits 0" test "$RC" -eq 0
expect "i5 local entry skipped with notice" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'nothing to install' ; grep -q 'skipping local' '$BASE/i.err'"

echo "=== I6: run from subdirectory still installs at project root ==="
P=$(new_proj i6)
seed_lock "$P" alpha skills/alpha
mkdir -p "$P/sub/dir"
OUT=$(cd "$P/sub/dir" && HOME="$HOMEBOX" "$P/bin/ai-files-skills-install" </dev/null 2>&1); RC=$?
export OUT RC
expect "i6 installs into project root despite subdir cwd" \
    bash -c "test \$RC -eq 0 && test -f '$P/.ai-files/skills/alpha/SKILL.md'"

echo "=== I7: repo-root skill (empty skill_dir_rel) installs ==="
P=$(new_proj i7)
seed_lock "$P" rooty ""
run_install "$P"
expect "i7 root-level skill installed" \
    bash -c "test \$RC -eq 0 && test -f '$P/.ai-files/skills/rooty/SKILL.md'"

echo "=== I8: gh engine delegates to gh skill install ==="
P=$(new_proj i8)
mkdir -p "$P/fakebin"
cat > "$P/fakebin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$GHCALLS"
if [[ "$1" == "skill" && "$2" == "install" ]]; then
    shift 2
    sel="$1"; shift
    dir=""; pin=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir) dir="$2"; shift ;;
            --pin) pin="$2"; shift ;;
        esac
        shift
    done
    leaf="$(basename "$sel")"
    mkdir -p "$dir/$leaf"
    printf -- '---\nname: %s\ndescription: gh-injected\n---\nbody\n' "$leaf" > "$dir/$leaf/SKILL.md"
fi
exit 0
GH
chmod +x "$P/fakebin/gh"
export GHCALLS="$BASE/gh-calls"; : > "$GHCALLS"
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" \
    add ghalpha --source octo/widgets --skill-path skills/alpha/SKILL.md --hash deadbeef >/dev/null 2>&1
OUT=$(cd "$P" && HOME="$HOMEBOX" PATH="$P/fakebin:$PATH" AI_FILES_SKILLS_ENGINE=gh \
    "$P/bin/ai-files-skills-install" </dev/null 2>"$BASE/i8.err"); RC=$?
export OUT RC
expect "i8 exits 0" test "$RC" -eq 0
grep -q "skill install octo/widgets skills/alpha --dir $P/.ai-files/skills/ --force" "$GHCALLS" \
    && ok "i8 gh received spec, path selector and --dir" \
    || bad "i8 gh invocation (got: $(cat "$GHCALLS"))"
expect "i8 gh-created dir renamed to lock key" test -f "$P/.ai-files/skills/ghalpha/SKILL.md"
expect "i8 lock re-stamped with real hash" \
    python3 -c "import json,re;e=json.load(open('$P/skills-lock.json'))['skills']['ghalpha'];assert re.fullmatch('[0-9a-f]{64}',e['computedHash'])"

echo "=== I9: gh absent (engine auto) installs via clone ==="
P=$(new_proj i9)
seed_lock "$P" alpha skills/alpha
# Minimal PATH with everything the scripts need EXCEPT gh — guarantees
# `command -v gh` fails even on hosts that have gh installed.
MIN="$P/minbin"; mkdir -p "$MIN"
for c in bash sh git python3 timeout mktemp rm mkdir ls ln comm cp mv head basename \
         dirname find grep sed awk sort sha256sum realpath readlink cat tar; do
    command -v "$c" >/dev/null 2>&1 && ln -s "$(command -v "$c")" "$MIN/$c"
done
OUT=$(cd "$P" && env -u AI_FILES_SKILLS_ENGINE HOME="$HOMEBOX" PATH="$MIN" \
    "$P/bin/ai-files-skills-install" </dev/null 2>"$BASE/i9.err"); RC=$?
export OUT RC
expect "i9 exits 0 with gh absent from PATH" test "$RC" -eq 0
expect "i9 skill installed via clone fallback" test -f "$P/.ai-files/skills/alpha/SKILL.md"
expect "i9 linked into .agents" test -L "$P/.agents/skills/alpha"

echo "=== I10: gh present but install fails — falls back to clone ==="
P=$(new_proj i10)
seed_lock "$P" alpha skills/alpha
mkdir -p "$P/badgh"
cat > "$P/badgh/gh" <<'GH'
#!/usr/bin/env bash
# skills support detected (--help succeeds), but installs fail
[[ "$1 $2" == "skill install" && "$3" == "--help" ]] && exit 0
[[ "$1" == "skill" ]] && exit 1
exit 0
GH
chmod +x "$P/badgh/gh"
OUT=$(cd "$P" && env -u AI_FILES_SKILLS_ENGINE HOME="$HOMEBOX" PATH="$P/badgh:$PATH" \
    "$P/bin/ai-files-skills-install" </dev/null 2>"$BASE/i10.err"); RC=$?
export OUT RC
expect "i10 exits 0 despite gh failure" test "$RC" -eq 0
expect "i10 skill installed via clone fallback" test -f "$P/.ai-files/skills/alpha/SKILL.md"
expect "i10 fallback notice printed" grep -q "gh skill install failed, using git clone" "$BASE/i10.err"

echo "=== I11: gh present without skills support — engine auto uses clone ==="
P=$(new_proj i11)
seed_lock "$P" alpha skills/alpha
mkdir -p "$P/plaingh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$P/plaingh/gh"   # gh, but no skills extension
chmod +x "$P/plaingh/gh"
OUT=$(cd "$P" && env -u AI_FILES_SKILLS_ENGINE HOME="$HOMEBOX" PATH="$P/plaingh:$PATH" \
    "$P/bin/ai-files-skills-install" </dev/null 2>"$BASE/i11.err"); RC=$?
export OUT RC
expect "i11 exits 0 when gh lacks skills support" test "$RC" -eq 0
expect "i11 skill installed via clone" test -f "$P/.ai-files/skills/alpha/SKILL.md"

echo "=== I12: raw lock key installs to sanitized dir, re-stamps raw key ==="
P=$(new_proj i12)
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" \
    add "Fancy.Pkg!" --source octo/widgets --skill-path skills/alpha/SKILL.md --hash deadbeefcafe0123 >/dev/null 2>&1
run_install "$P"
expect "i12 exits 0" test "$RC" -eq 0
expect "i12 installs into sanitized dir fancy.pkg" test -f "$P/.ai-files/skills/fancy.pkg/SKILL.md"
expect "i12 links sanitized dir in all four agent dirs" \
    bash -c "for a in claude kilo opencode agents; do test -L '$P'/.\$a/skills/fancy.pkg || exit 1; done"
expect "i12 re-stamps under raw key Fancy.Pkg! with real hash" \
    python3 -c "
import json,re
d=json.load(open('$P/skills-lock.json'))
e=d['skills']['Fancy.Pkg!']
assert e['sourceType']=='github' and e['source']=='octo/widgets'
assert re.fullmatch('[0-9a-f]{64}',e['computedHash'])"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
