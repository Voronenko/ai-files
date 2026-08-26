#!/usr/bin/env bash
# Test suite for the marketplace tooling:
#   - bin/ai-files-marketplace          (dispatcher routing)
#   - bin/ai-files-marketplace-install  (unattended registration flows)
#   - bin/ai-files-marketplace-update   (marketplace.json generation)
#
# Conventions match the other suites: self-cleaning mktemp workspace,
# PASS/FAIL counters, exit 1 on any failure. A fake `claude` CLI records its
# arguments so registration calls can be asserted without Claude Code.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
expect() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

for cmd in git jq python3; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing $cmd" >&2; exit 2; }
done
python3 -c 'import yaml' >/dev/null 2>&1 \
    || { echo "ERROR: PyYAML required (python3 -m pip install pyyaml)" >&2; exit 2; }

BASE="$(mktemp -d "${TMPDIR:-/tmp}/ai-files-marketplace-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

VENDOR_URL="https://raw.githubusercontent.com/nfraops/ai-files-vendor-skills/master/.claude-plugin/marketplace.json"

# ---------------------------------------------------------------- fixture
FIX="$BASE/mkt-fixture"
mkdir -p "$FIX/bin" "$FIX/skills" "$FIX/.claude-plugin"
cp "$REPO_ROOT/bin/ai-files-marketplace"         "$FIX/bin/"
cp "$REPO_ROOT/bin/ai-files-marketplace-install" "$FIX/bin/"
cp "$REPO_ROOT/bin/ai-files-marketplace-update"  "$FIX/bin/"
chmod +x "$FIX/bin/"*
git -C "$FIX" init -q
git -C "$FIX" remote add origin "https://github.com/acme/ai-files.git"

mk_skill() { # <dir> [frontmatter-lines...]  (empty frontmatter -> raw body only)
    local d="$FIX/skills/$1"; shift
    mkdir -p "$d"
    { [ $# -eq 0 ] || [ -z "$1" ]; } && { printf 'body only\n' > "$d/SKILL.md"; return; }
    { printf -- '---\n%s\n---\nbody\n' "$1"; } > "$d/SKILL.md"
}

mk_skill adr-tools      'name: adr-tools
description: ADR tooling'
mk_skill mermaid        'name: mermaid
description: Diagrams'
mk_skill obsidian-cli   'name: obsidian-cli
description: Obsidian CLI'
mk_skill plantuml       'name: plantuml
description: UML'
mk_skill lnav           'name: lnav
description: Logs'
mk_skill lnav-unattended 'name: lnav-unattended
description: Logs unattended'
# prefix idempotency probe: frontmatter already carries the prefix
mk_skill graphify       'name: ai-files-graphify
description: Knowledge graphs'
# SKIP_SKILLS member
mk_skill a-template     'name: a-template
description: Template'
# malformed YAML -> graceful fallbacks
mk_skill broken-yaml    'name: [unclosed'

# fake claude CLI: logs argv, optional failure injection for `add`
SHIMS="$BASE/shims"
mkdir -p "$SHIMS"
cat > "$SHIMS/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CLAUDE_LOG:?}"
if [ "${FAKE_CLAUDE_FAIL:-0}" = "1" ] && [ "${1:-}" = "plugin" ] && [ "${2:-}" = "marketplace" ] && [ "${3:-}" = "add" ]; then
    exit 9
fi
exit 0
EOF
chmod +x "$SHIMS/claude"

LOG="$BASE/claude.log"

run_update() { (cd "$FIX" && python3 bin/ai-files-marketplace-update) >/dev/null 2>&1; }

echo "=== U1-U4: marketplace.json generation ==="
rm -f "$FIX/.claude-plugin/marketplace.json"
run_update
expect "u1 generates valid JSON" bash -c "jq -e . '$FIX/.claude-plugin/marketplace.json' >/dev/null 2>&1"
NAMES="$(jq -r '.plugins[].name' "$FIX/.claude-plugin/marketplace.json" | sort)"
export NAMES
expect "u2 plugin set matches groups+individuals (prefix once)" \
    bash -c "printf '%s\n' \"\$NAMES\" | diff - <(printf '%s\n' ai-files-broken-yaml ai-files-dev-swiss-knife ai-files-graphify ai-files-lnav | sort) >/dev/null"
expect "u3 dev-swiss-knife merges 4 skills incl plantuml" \
    bash -c "jq -e '.plugins[] | select(.name==\"ai-files-dev-swiss-knife\") | (.skills|length)==4 and (.skills|index(\"./skills/plantuml\")) != null' '$FIX/.claude-plugin/marketplace.json'"
expect "u4 lnav group merges 2 skills" \
    bash -c "jq -e '.plugins[] | select(.name==\"ai-files-lnav\") | (.skills|length)==2' '$FIX/.claude-plugin/marketplace.json'"
expect "u5 a-template skipped" \
    bash -c "jq -e '[.plugins[].skills[]] | any(. == \"./skills/a-template\") | not' '$FIX/.claude-plugin/marketplace.json'"
expect "u6 broken-YAML falls back to dir name + default description" \
    bash -c "jq -e '.plugins[] | select(.name==\"ai-files-broken-yaml\") | .description == \"Skills from broken-yaml\"' '$FIX/.claude-plugin/marketplace.json'"
expect "u7 metadata fields present" \
    bash -c "jq -e '.name == \"ai-files-skills\" and .owner.name == \"ai-files\" and .[\"\$schema\"] != null' '$FIX/.claude-plugin/marketplace.json'"
cp "$FIX/.claude-plugin/marketplace.json" "$BASE/before.json"
run_update
expect "u8 regeneration is idempotent" cmp -s "$BASE/before.json" "$FIX/.claude-plugin/marketplace.json"

echo "=== I1: unattended -y --scope user registers both marketplaces ==="
INS="$FIX/bin/ai-files-marketplace-install"
: > "$LOG"
CLAUDE_LOG="$LOG" PATH="$SHIMS:$PATH" "$INS" --yes --scope user >/dev/null 2>&1
expect "i1 exits 0" test $? -eq 0
expect "i1 adds github shorthand with user scope" \
    bash -c "grep -Fxq 'plugin marketplace add acme/ai-files --scope user' '$LOG'"
expect "i1 adds vendor marketplace url" \
    bash -c "grep -Fxq \"plugin marketplace add $VENDOR_URL --scope user\" '$LOG'"
expect "i1 ends with marketplace list" \
    bash -c "grep -Fxq 'plugin marketplace list' '$LOG'"
expect "i1 exactly two add calls" test "$(grep -c 'marketplace add' "$LOG")" -eq 2

echo "=== I2: non-github remote falls back to local repo path ==="
FIX2="$BASE/nothub"
mkdir -p "$FIX2/bin"
cp "$REPO_ROOT/bin/ai-files-marketplace-install" "$FIX2/bin/"
git -C "$FIX2" init -q
git -C "$FIX2" remote add origin "https://example.com/org/repo.git"
: > "$LOG"
CLAUDE_LOG="$LOG" PATH="$SHIMS:$PATH" "$FIX2/bin/ai-files-marketplace-install" -y >/dev/null 2>&1
expect "i2 adds local repository path instead of shorthand" \
    bash -c "grep -Fq \"plugin marketplace add $FIX2 --scope project\" '$LOG'"

echo "=== I3: interactive y/y equals -y with default scope project ==="
: > "$LOG"
printf 'y\ny\n' | CLAUDE_LOG="$LOG" PATH="$SHIMS:$PATH" "$INS" >/dev/null 2>&1
expect "i3 rc0 and both adds use project scope" \
    bash -c "test \$(grep -c 'marketplace add .* --scope project' '$LOG') -eq 2"

echo "=== I4: answering n/n performs zero registrations ==="
: > "$LOG"
printf 'n\nn\n' | CLAUDE_LOG="$LOG" PATH="$SHIMS:$PATH" "$INS" >/dev/null 2>&1
expect "i4 exits 0" test $? -eq 0
expect "i4 zero add calls, list still shown" \
    bash -c "test \$(grep -c 'marketplace add' '$LOG') -eq 0 && grep -Fq 'plugin marketplace list' '$LOG'"

echo "=== I5: failed registrations propagate to exit code ==="
: > "$LOG"
ERR_OUT=$(FAKE_CLAUDE_FAIL=1 CLAUDE_LOG="$LOG" PATH="$SHIMS:$PATH" "$INS" -y 2>&1 </dev/null)
RC=$?
expect "i5 exits non-zero on failed adds" test $RC -ne 0
COUNT=$(printf '%s' "$ERR_OUT" | grep -c 'Failed to register')
export COUNT
expect "i5 both failure markers emitted on stderr" \
    bash -c "test \"\$COUNT\" -ge 2"

echo "=== I6: option validation ==="
"$INS" --bogus >/dev/null 2>&1
expect "i6 unknown option rejected" test $? -ne 0
"$INS" --scope >/dev/null 2>&1
expect "i6 --scope without value rejected" test $? -ne 0
"$INS" --scope bogus >/dev/null 2>&1
expect "i6 invalid scope rejected" test $? -ne 0
"$INS" --help >/dev/null 2>&1
expect "i6 --help exits 0" test $? -eq 0

echo "=== I7: missing claude CLI fails fast ==="
NOCLAUDE="$BASE/noclaudefix"
mkdir -p "$NOCLAUDE/bin"
cp "$REPO_ROOT/bin/ai-files-marketplace-install" "$NOCLAUDE/bin/"
GITONLY="$BASE/gitonly"; mkdir -p "$GITONLY"
ln -sf "$(command -v git)" "$GITONLY/git"
ln -sf "$(command -v sed)" "$GITONLY/sed"
ln -sf /usr/bin/env "$GITONLY/env"
ln -sf "$(command -v bash)" "$GITONLY/bash"
(cd "$NOCLAUDE" && PATH="$GITONLY" "$NOCLAUDE/bin/ai-files-marketplace-install" -y >/dev/null 2>&1)
expect "i7 exits non-zero without claude" test $? -ne 0

echo "=== D: dispatcher routing ==="
DISP="$FIX/bin/ai-files-marketplace"
"$DISP" help >/dev/null 2>&1
expect "d1 help exits 0" test $? -eq 0
"$DISP" frobnicate >/dev/null 2>&1
expect "d2 unknown command exits 1" test $? -ne 0
"$DISP" install --help >/dev/null 2>&1
expect "d3 install --help passthrough exits 0" test $? -eq 0
rm -f "$FIX/.claude-plugin/marketplace.json"
(cd "$FIX" && "$DISP" update) >/dev/null 2>&1
expect "d4 update passthrough regenerates json" \
    bash -c "jq -e . '$FIX/.claude-plugin/marketplace.json' >/dev/null 2>&1"

echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
