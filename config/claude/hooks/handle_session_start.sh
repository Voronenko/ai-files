#!/bin/bash
#
# Claude Code SessionStart hook.
#
# Reads JSON payload via stdin, e.g.:
#   {
#     "hook_event_name": "SessionStart",
#     "cwd": "/Users/.../project",
#     "source": "startup"
#   }
#
# Emits a JSON object on stdout whose
# hookSpecificOutput.additionalContext is injected into Claude's context
# window at the start of the session. This complements the 🎯/🚫 indicator
# in statusline.sh with a conversational nudge:
#   - active workout session -> remind the user and offer /workout.end
#   - no active session       -> invite the user to /workout.start
#
# Fails open: any unexpected error exits 0 so session start is never blocked.

set -u

INPUT="$(cat)"

# Resolve the project directory: prefer the hook payload's cwd, fall back to
# $CLAUDE_PROJECT_DIR, then to the current working directory.
CWD=""
if command -v jq >/dev/null 2>&1; then
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
fi
[ -z "$CWD" ] && CWD="${CLAUDE_PROJECT_DIR:-}"
[ -z "$CWD" ] && CWD="$PWD"

SESSIONS_DIR="$CWD/.ai-files/sessions"
POINTER_FILE="$SESSIONS_DIR/.current-session"

# A session is "active" only when the pointer is non-empty AND the referenced
# session markdown file actually exists (guards against stale pointers).
ACTIVE_NAME=""
ACTIVE_FILE=""
if [ -s "$POINTER_FILE" ]; then
  RAW="$(tr -d '\r\n' < "$POINTER_FILE")"
  if [ -n "$RAW" ]; then
    SESSION_MD="$SESSIONS_DIR/$RAW"
    if [ -f "$SESSION_MD" ]; then
      ACTIVE_FILE="$RAW"
      # Strip the leading date-time prefix (YYYY-MM-DD-HHMM-) and trailing .md
      ACTIVE_NAME="$(basename "$RAW" \
        | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}-//' \
        | sed 's/\.md$//')"
    fi
  fi
fi

# Emit the additionalContext payload as JSON.
emit() {
  # $1 = the context string to inject.
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg ctx "$1" \
      '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
  else
    # Minimal fallback: escape the bare minimum of JSON metacharacters.
    ESC="$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$ESC"
  fi
}

if [ -n "$ACTIVE_FILE" ]; then
  emit "An active workout session is in progress: \"$ACTIVE_NAME\" (session file: .ai-files/sessions/$ACTIVE_FILE). Briefly inform the user this session is still active and ask whether to wrap it up with /workout.end or continue working on it."
else
  emit "No active workout session is tracked. Briefly invite the user to start a new coding workout session with /workout.start if they'd like structured session tracking."
fi

exit 0
