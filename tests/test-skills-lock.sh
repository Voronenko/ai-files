#!/usr/bin/env bash
# Test suite for `ai-files-skills-lock` (skills-lock.json helper).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$REPO_ROOT/bin/ai-files-skills-lock"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in python3 sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-lock-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

P="$BASE/proj"              # lock dir
SD="$P/.ai-files/skills"    # skills dir
mkdir -p "$SD"

run_lock() { # args after the subcommand; captures OUT / RC against $P
    OUT=$("$LOCK" --dir "$P" --skills-dir "$SD" "$@" 2>"$BASE/lock.err"); RC=$?
    export OUT RC
}

lock_in() { # <lockdir> <args...>
    local d="$1"; shift
    "$LOCK" --dir "$d" --skills-dir "$d/.ai-files/skills" "$@"
}

echo "=== L1: folder hash matches independently computed sha256 ==="
D="$SD/demo"; mkdir -p "$D/sub"
printf -- '---\nname: t\ndescription: d\n---\nx\n' > "$D/SKILL.md"
printf 'hello\n' > "$D/sub/b.txt"
EXPECTED=$({ printf 'SKILL.md'; cat "$D/SKILL.md"; printf 'sub/b.txt'; cat "$D/sub/b.txt"; } | sha256sum | cut -d' ' -f1)
GOT=$("$LOCK" hash "$D")
expect "l1 hash matches path+content stream" test "$GOT" = "$EXPECTED"

echo "=== L2: add writes sorted keys, 2-space indent, classified sources ==="
run_lock add b-demo --source octo/widgets --hash "$EXPECTED"
run_lock add a-demo --source https://gitlab.com/x/y.git --hash "$EXPECTED"
expect "l2 keys sorted alphabetically" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert list(d['skills'])==['a-demo','b-demo']"
expect "l2 2-space indent" grep -q '^  "version": 1,$' "$P/skills-lock.json"
expect "l2 trailing newline" test -z "$(tail -c1 "$P/skills-lock.json")"
expect "l2 github shorthand classified" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['b-demo'];assert e['sourceType']=='github' and e['source']=='octo/widgets' and 'sourceUrl' not in e and 'ref' not in e"
expect "l2 gitlab url classified as gitlab with canonical .git source/sourceUrl" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['a-demo'];assert e['sourceType']=='gitlab' and e['source']=='https://gitlab.com/x/y.git' and e['sourceUrl']=='https://gitlab.com/x/y.git'"

echo "=== L3: idempotent rewrite is byte-identical ==="
cp "$P/skills-lock.json" "$BASE/before.json"
run_lock add b-demo --source octo/widgets --hash "$EXPECTED"
expect "l3 rewrite byte-identical (no timestamps)" cmp -s "$BASE/before.json" "$P/skills-lock.json"

echo "=== L4: local source portability round-trip ==="
mkdir -p "$P/other/src" "$BASE/outside"
run_lock add local-one --source "$P/other/src" --hash "$EXPECTED"
expect "l4 in-tree source stored as ./" grep -q '"\./other/src"' "$P/skills-lock.json"
OUT=$("$LOCK" --dir "$P" --skills-dir "$SD" list --json)
expect "l4 read-back absolutizes local source" \
    bash -c "printf '%s' \"\$OUT\" | grep -qF '$P/other/src'"
run_lock add ext-one --source "$BASE/outside" --hash "$EXPECTED"
expect "l4 escaping source kept bare ../" grep -q '"\.\./outside"' "$P/skills-lock.json"

echo "=== L5: corrupt lock (merge markers) treated as empty ==="
printf '{\n<<<<<<< HEAD\n"version": 1\n=======\n"version": 2\n>>>>>>> b\n}\n' > "$P/skills-lock.json"
run_lock add mk-demo --source octo/widgets --hash "$EXPECTED"
expect "l5 corrupt lock replaced by valid one" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert d['version']==1 and 'mk-demo' in d['skills']"

echo "=== L6: version < 1 treated as empty ==="
printf '{"version": 0, "skills": {"old": {"source":"x","sourceType":"github","computedHash":"y"}}}\n' > "$P/skills-lock.json"
run_lock add v-demo --source octo/widgets --hash "$EXPECTED"
expect "l6 stale entries dropped, new entry kept" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert 'old' not in d['skills'] and 'v-demo' in d['skills']"

echo "=== L7: remove semantics ==="
run_lock remove not-there
expect "l7 remove absent exits 1" test "$RC" -eq 1
run_lock remove v-demo
expect "l7 remove present exits 0 and drops entry" \
    bash -c "test '$RC' -eq 0 && ! grep -q '\"v-demo\"' '$P/skills-lock.json'"

echo "=== L8: hash skips .git, node_modules and symlinks ==="
C="$SD/clean"; mkdir -p "$C"
printf 'body\n' > "$C/SKILL.md"
D2="$SD/dirty"; mkdir -p "$D2/.git" "$D2/node_modules"
printf 'body\n' > "$D2/SKILL.md"
printf 'junk\n' > "$D2/.git/config"
printf 'junk\n' > "$D2/node_modules/pkg.js"
ln -sf /etc/hostname "$D2/link.txt"
expect "l8 junk dirs and symlinks excluded from hash" \
    test "$("$LOCK" hash "$C")" = "$("$LOCK" hash "$D2")"

echo "=== L9: byte-exact output (vercel field order) ==="
P2="$BASE/exact"; mkdir -p "$P2/.ai-files/skills"
lock_in "$P2" add demo --source octo/widgets --hash deadbeef >/dev/null 2>&1
cat > "$BASE/expected.json" <<'EOF'
{
  "version": 1,
  "skills": {
    "demo": {
      "source": "octo/widgets",
      "sourceType": "github",
      "computedHash": "deadbeef"
    }
  }
}
EOF
expect "l9 file byte-identical to vercel-shaped JSON" cmp -s "$BASE/expected.json" "$P2/skills-lock.json"

echo "=== L10: missing / refresh reconcile against disk ==="
P3="$BASE/recon"; SD3="$P3/.ai-files/skills"; mkdir -p "$SD3/there"
printf -- '---\nname: there\ndescription: d\n---\nx\n' > "$SD3/there/SKILL.md"
lock_in "$P3" add there --source octo/x --hash deadbeef >/dev/null 2>&1
lock_in "$P3" add gone --source octo/y --hash deadbeef >/dev/null 2>&1
OUT=$(lock_in "$P3" missing)
expect "l10 missing lists only entries without a dir" test "$OUT" = "gone"
lock_in "$P3" refresh >/dev/null 2>&1
expect "l10 refresh drops vanished entries" \
    python3 -c "import json;d=json.load(open('$P3/skills-lock.json'));assert list(d['skills'])==['there']"

echo "=== L11: dir subcommand — vercel sanitizeName port ==="
expect "l11 Fancy.Pkg! -> fancy.pkg" test "$("$LOCK" dir 'Fancy.Pkg!')" = "fancy.pkg"
expect "l11 Alpha Tools -> alpha-tools" test "$("$LOCK" dir 'Alpha Tools')" = "alpha-tools"
expect "l11 '..' falls back to unnamed-skill" test "$("$LOCK" dir '..')" = "unnamed-skill"
expect "l11 dots and underscores kept" test "$("$LOCK" dir 'a_b.C d')" = "a_b.c-d"
expect "l11 idempotent on sanitized input (zero-migration proof)" \
    test "$("$LOCK" dir 'fancy.pkg')" = "fancy.pkg"

echo "=== L12: classification parity (well-known, refs, prefixes) ==="
run_lock add wk --source https://example.com/foo --hash deadbeef
expect "l12 other-host https (no .git) is well-known with hostname source" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['wk'];assert e['sourceType']=='well-known' and e['source']=='example.com' and e['sourceUrl']=='https://example.com/foo' and 'ref' not in e"
run_lock add frag --source octo/widgets#v1.2.0 --hash deadbeef
expect "l12 shorthand #ref splits into ref" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['frag'];assert e['sourceType']=='github' and e['source']=='octo/widgets' and e['ref']=='v1.2.0'"
run_lock add gltree --source "https://gitlab.com/grp/sub/r/-/tree/v2" --hash deadbeef
expect "l12 gitlab /-/tree ref parsed" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['gltree'];assert e['sourceType']=='gitlab' and e['source']=='https://gitlab.com/grp/sub/r.git' and e['ref']=='v2'"
run_lock add pref --source "gitlab:octo/tools" --hash deadbeef
expect "l12 gitlab: prefix normalized" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['pref'];assert e['sourceType']=='gitlab' and e['source']=='https://gitlab.com/octo/tools.git'"
run_lock add ghtree --source "https://github.com/o/r/tree/v9/skills/x" --hash deadbeef
expect "l12 github /tree ref parsed" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['ghtree'];assert e['sourceType']=='github' and e['source']=='o/r' and e['ref']=='v9'"

echo "=== L13: raw-key add maps to sanitized dir; plan emits dir column ==="
P4="$BASE/keys"; SD4="$P4/.ai-files/skills"; mkdir -p "$SD4/fancy.pkg"
printf -- '---\nname: Fancy.Pkg!\ndescription: d\n---\nx\n' > "$SD4/fancy.pkg/SKILL.md"
lock_in "$P4" add 'Fancy.Pkg!' --source octo/widgets --skill-path skills/fancy/SKILL.md --hash deadbeef >/dev/null 2>&1
expect "l13 raw key stored verbatim" \
    python3 -c "import json;d=json.load(open('$P4/skills-lock.json'));assert 'Fancy.Pkg!' in d['skills']"
OUT=$(lock_in "$P4" missing)
expect "l13 missing maps key to sanitized dir (present → not missing)" test "$OUT" = ""
rm -rf "$SD4/fancy.pkg"
OUT=$(lock_in "$P4" plan)
expect "l13 plan row ends with dir column fancy.pkg" \
    bash -c "printf '%s' \"\$OUT\" | grep -q 'fancy.pkg\$'"
OUT=$(lock_in "$P4" missing)
expect "l13 missing once sanitized dir removed" test "$OUT" = "Fancy.Pkg!"

echo "=== L14: remove resolves by sanitized dir (vercel parity) ==="
lock_in "$P4" remove fancy.pkg >/dev/null 2>&1
expect "l14 remove 'fancy.pkg' dropped key 'Fancy.Pkg!'" \
    python3 -c "import json;d=json.load(open('$P4/skills-lock.json'));assert 'Fancy.Pkg!' not in d['skills']"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
