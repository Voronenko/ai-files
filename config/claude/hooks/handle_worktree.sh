#!/bin/bash
#
# Claude Code passes a JSON payload via stdin:
#
# WorktreeCreate:
#   { "hook_event_name": "WorktreeCreate", "cwd": "/Users/.../project", "name": "my-feature" }
#
# WorktreeRemove:
#   { "hook_event_name": "WorktreeRemove", "cwd": "/Users/.../project", "worktree_path": "/Users/.../project-my-feature" }

INPUT=$(cat)

if ! command -v jq &>/dev/null; then
  echo "jq is required but not installed" >&2
  exit 1
fi

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/worktree.log"
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$HOOK_EVENT] $*" >> "$LOG_FILE"
}
# Create a git worktree at ../{project}-{name} branching off the current branch.
# Outputs the worktree path to stdout (Claude Code reads this to set the working directory).
worktree_create() {
  local NAME
  NAME=$(echo "$INPUT" | jq -r '.name')

  local PROJECT_NAME PARENT_DIR WORKTREE_DIR BRANCH_NAME
  PROJECT_NAME=$(basename "$CWD")
  PARENT_DIR=$(cd "$CWD/.." && pwd)
  WORKTREE_DIR="$PARENT_DIR/$PROJECT_NAME-$NAME"
  BRANCH_NAME="worktree-$NAME"

  log "Creating worktree: name=$NAME project=$PROJECT_NAME"
  log "  path=$WORKTREE_DIR branch=$BRANCH_NAME"

  # Use current branch as base
  local BASE_BRANCH
  BASE_BRANCH=$(cd "$CWD" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
  : "${BASE_BRANCH:=master}"
  log "  base=$BASE_BRANCH"

  # Reuse existing worktree if it already exists (e.g. second subtask in same session)
  if [ -d "$WORKTREE_DIR" ]; then
    log "Worktree already exists at $WORKTREE_DIR, reusing"
    echo "$WORKTREE_DIR"
    exit 0
  fi

  # Create git worktree in sibling directory
  cd "$CWD" || exit 1

  # If the branch already exists (leftover from a previous run), reuse it
  # instead of creating with -b (which fails on existing branches)
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    log "Branch $BRANCH_NAME already exists, reusing"
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME" >&2 || {
      log "FAILED to create worktree: $NAME"
      echo "Failed to create worktree: $NAME" >&2
      exit 1
    }
  else
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "$BASE_BRANCH" >&2 || {
      log "FAILED to create worktree: $NAME"
      echo "Failed to create worktree: $NAME" >&2
      exit 1
    }
  fi

  # Copy .env to the new worktree (hard copy, no symlink)
  if [ -f "$CWD/.env" ]; then
    cp "$CWD/.env" "$WORKTREE_DIR/.env"
    log "Copied .env to worktree"
  else
    log "No .env found in $CWD, skipping copy"
  fi

  log "Created worktree successfully at $WORKTREE_DIR"

  # Output the worktree path (the ONLY stdout Claude Code reads)
  echo "$WORKTREE_DIR"
}

# Remove a worktree directory and delete its associated branch.
# Finds the main repo from the worktree's git metadata to run cleanup from there.
worktree_remove() {
  local WORKTREE_PATH
  WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path')

  log "Removing worktree: path=$WORKTREE_PATH"

  if [ ! -d "$WORKTREE_PATH" ]; then
    log "Worktree directory does not exist, skipping"
    exit 0
  fi

  # Find main repo (first entry in worktree list)
  local MAIN_REPO BRANCH_NAME
  MAIN_REPO=$(git -C "$WORKTREE_PATH" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
  BRANCH_NAME="worktree-$(basename "$WORKTREE_PATH")"

  log "  main_repo=$MAIN_REPO branch=$BRANCH_NAME"

  # Remove worktree and branch
  cd "$MAIN_REPO" 2>/dev/null || exit 0
  git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"
  git branch -D "$BRANCH_NAME" 2>/dev/null

  log "Removed worktree successfully"
}

# Parse hook events
case "$HOOK_EVENT" in
  WorktreeCreate) worktree_create ;;
  WorktreeRemove) worktree_remove ;;
esac
