#!/bin/bash
#https://code.claude.com/docs/en/statusline

# Read JSON input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')

# Extract values using jq
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')

# Check for active session
SESSION_INFO=""
SESSION_FILE="./.ai-files/sessions/.current-goal"
if [ -f "$SESSION_FILE" ]; then
    SESSION_CONTENT=$(cat "$SESSION_FILE" 2>/dev/null | tr -d '\n')
    if [ -n "$SESSION_CONTENT" ]; then
        # Extract useful part from filename (remove date-time prefix and .md extension)
        SESSION_NAME=$(basename "$SESSION_CONTENT" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}-//' | sed 's/\.md$//')
        if [ -n "$SESSION_NAME" ]; then
            SESSION_INFO=" | 🎯 $SESSION_NAME"
        fi
    fi
fi

# If no session info, show NO ACTIVE SESSION
if [ -z "$SESSION_INFO" ]; then
    SESSION_INFO=" | 🚫 NO ACTIVE SESSION"
fi

# Show git branch if in a git repo
GIT_BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" | 🌿 $BRANCH"
    fi
fi

echo "[$MODEL_DISPLAY] 📁 ${CURRENT_DIR##*/}$GIT_BRANCH$SESSION_INFO"
