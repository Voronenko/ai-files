#!/usr/bin/env bash
# Test suite: native vercel-labs `skills` CLI interoperates with our
# skills-lock.json (reads it, restores from it, and its rewrite stays
# readable by our tooling).
#
# The lock entry uses a git-type source (https://gitlab.example/…) because the
# native CLI fetches github-type sources via the GitHub API (network, ignores
# git insteadOf rewrites), while git-type sources go through `git clone`,
# which honors the hermetic rewrite in the sandboxed HOME.
#
# The native CLI is resolved in this order:
#   1. $VERCEL_SKILLS_CLI  — explicit command prefix, e.g.
#        "node /home/slavko/tmp/skills/dist/cli.mjs"
#   2. npx --yes skills@$VERCEL_SKILLS_NPM_VERSION (default 1.5.23)
#   3. SKIP — the suite passes with notices (offline / no node / no npx)
#
# Note: the native CLI exits 0 even when an install fails, so assertions
# check outcomes (installed files, output text), not just exit codes.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$REPO_ROOT/bin/ai-files-skills-lock"

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
skip() { SKIP=$((SKIP+1)); echo "SKIP: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in git python3 node; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done

#--- resolve the native CLI ------------------------------------------------
NATIVE_CLI=""
if [[ -n "${VERCEL_SKILLS_CLI:-}" ]]; then
    if timeout 60 $VERCEL_SKILLS_CLI --help >/dev/null 2>&1; then
        NATIVE_CLI="$VERCEL_SKILLS_CLI"
    else
        skip "v0 \$VERCEL_SKILLS_CLI set but not runnable: $VERCEL_SKILLS_CLI"
    fi
elif command -v npx >/dev/null 2>&1; then
    NPM_VER="${VERCEL_SKILLS_NPM_VERSION:-1.5.23}"
    if timeout 120 npx --yes "skills@$NPM_VER" --help >/dev/null 2>&1; then
        NATIVE_CLI="npx --yes skills@$NPM_VER"
    else
        skip "v0 npx skills@$NPM_VER unavailable (offline?)"
    fi
else
    skip "v0 no npx and no \$VERCEL_SKILLS_CLI — nothing to interop with"
fi

if [[ -z "$NATIVE_CLI" ]]; then
    echo ""
    echo "================================"
    echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    exit 0
fi
ok "v0 native CLI resolved: $NATIVE_CLI"

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-interop-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

#--- fixture: git repo the fake git source rewrites to ---------------------
FIX="$BASE/repo"
mkdir -p "$FIX"
git -C "$FIX" init -q
mkdir -p "$FIX/skills/alpha" "$FIX/skills/fancy"
# 'alpha' is sanitize-stable; 'Fancy.Pkg!' is NOT — its lock key (raw name)
# differs from its installed dir (sanitizeName → fancy.pkg). Both shapes are
# exercised to prove full key/dir compatibility.
printf -- '---\nname: alpha\ndescription: Alpha desc\n---\nbody\n' > "$FIX/skills/alpha/SKILL.md"
printf -- '---\nname: Fancy.Pkg!\ndescription: Fancy desc\n---\nbody\n' > "$FIX/skills/fancy/SKILL.md"
git -C "$FIX" add -A
git -C "$FIX" -c user.email=t@example.com -c user.name=T commit -qm snapshot

FAKE_GIT_URL="https://gitlab.example/octo/widgets.git"
HB="$BASE/home"
mkdir -p "$HB"
git config --file "$HB/.gitconfig" url."file://$FIX".insteadOf "$FAKE_GIT_URL"

P="$BASE/proj"
mkdir -p "$P/.ai-files/skills"

run_native() { # <args...> — cwd $P, captures OUT/RC (combined stdout+stderr)
    OUT=$(cd "$P" && HOME="$HB" timeout 180 $NATIVE_CLI "$@" </dev/null 2>&1)
    RC=$?
    export OUT RC
}

#--- OUR tooling writes the lock -------------------------------------------
"$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" \
    add alpha --source "$FAKE_GIT_URL" --skill-path skills/alpha/SKILL.md --hash deadbeefcafe0123 >/dev/null 2>&1
expect "v1 our lock seeded (git entry, sourceUrl kept)" \
    python3 -c "import json;e=json.load(open('$P/skills-lock.json'))['skills']['alpha'];assert e['sourceType']=='git' and e['sourceUrl']=='$FAKE_GIT_URL'"

echo "=== V2: native ls tolerates our lock without errors ==="
run_native ls
expect "v2 native ls exits 0 with our lock present" test "$RC" -eq 0
if printf '%s' "$OUT" | grep -qE 'Installation failed|ERROR|Missing required'; then
    bad "v2 native ls output clean"
else
    ok "v2 native ls output clean"
fi

echo "=== V3: native experimental_install restores from our lock ==="
run_native experimental_install -y
expect "v3 native install exits 0" test "$RC" -eq 0
if printf '%s' "$OUT" | grep -q 'Installation failed'; then
    bad "v3 no 'Installation failed' in output"
else
    ok "v3 no 'Installation failed' in output"
fi
expect "v3 skill materialized by native install" \
    test -n "$(find "$P/.agents" "$P/.claude" -name SKILL.md -print -quit 2>/dev/null)"
run_native ls
expect "v3 native ls now lists the restored skill" \
    bash -c "printf '%s' \"\$OUT\" | grep -qi 'alpha'"

echo "=== V4: lock still valid JSON and readable by our tooling after their rewrite ==="
expect "v4 lock parses as JSON after native rewrite" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert d.get('version')==1 and isinstance(d.get('skills'),dict)"
OUT2=$("$LOCK" --dir "$P" --skills-dir "$P/.ai-files/skills" list 2>"$BASE/v4.err"); RC2=$?
export OUT2 RC2
expect "v4 our lock list exits 0 after native rewrite" test "$RC2" -eq 0
expect "v4 lock still holds at least one entry" \
    python3 -c "import json;d=json.load(open('$P/skills-lock.json'));assert d['skills']"
# ponytail: their rewrite keys by frontmatter name, ours by sanitized dir —
# both keys may coexist; we require validity, not byte-stability

echo "=== V5: our raw-key entry (name ≠ dir) restores via native CLI ==="
P2="$BASE/proj-rawkey"; mkdir -p "$P2/.ai-files/skills"
"$LOCK" --dir "$P2" --skills-dir "$P2/.ai-files/skills" \
    add "Fancy.Pkg!" --source "$FAKE_GIT_URL" --skill-path skills/fancy/SKILL.md --hash deadbeef >/dev/null 2>&1
OUT=$(cd "$P2" && HOME="$HB" timeout 180 $NATIVE_CLI experimental_install -y </dev/null 2>&1 | grep -viE 'npm (notice|warn)'); RC=$?
export OUT RC
expect "v5 native install exits 0" test "$RC" -eq 0
expect "v5 native materializes sanitizeName dir fancy.pkg" \
    test -f "$P2/.agents/skills/fancy.pkg/SKILL.md"
if printf '%s' "$OUT" | grep -q 'No matching skills'; then
    bad "v5 no 'No matching skills' for raw-key entry"
else
    ok "v5 no 'No matching skills' for raw-key entry"
fi

echo "=== V6: lock written by native CLI is consumed by our install ==="
P3="$BASE/proj-native"; mkdir -p "$P3/bin"
cp "$REPO_ROOT/bin/ai-files-skills-install" "$REPO_ROOT/bin/ai-files-skill-enable" \
   "$REPO_ROOT/bin/ai-files-skill-disable" "$LOCK" "$P3/bin/"
OUT=$(cd "$P3" && HOME="$HB" timeout 180 $NATIVE_CLI add "$FAKE_GIT_URL" --skill "Fancy.Pkg!" -y </dev/null 2>&1 | grep -viE 'npm (notice|warn)'); RC=$?
export OUT RC
expect "v6 native add exits 0" test "$RC" -eq 0
expect "v6 native wrote lock with raw key" \
    python3 -c "import json;d=json.load(open('$P3/skills-lock.json'));assert 'Fancy.Pkg!' in d['skills']"
OUT=$(cd "$P3" && HOME="$HB" PATH="$P3/bin:$PATH" AI_FILES_SKILLS_ENGINE=git \
    "$P3/bin/ai-files-skills-install" </dev/null 2>&1); RC=$?
export OUT RC
expect "v6 our install exits 0 on their lock" test "$RC" -eq 0
expect "v6 our install materializes .ai-files/skills/fancy.pkg" \
    test -f "$P3/.ai-files/skills/fancy.pkg/SKILL.md"
expect "v6 our install re-stamps under the raw key" \
    python3 -c "import json;e=json.load(open('$P3/skills-lock.json'))['skills']['Fancy.Pkg!'];assert e['sourceType']=='git'"
expect "v6 agent link created for sanitized dir" test -L "$P3/.claude/skills/fancy.pkg"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ $FAIL -eq 0 ]] || exit 1
