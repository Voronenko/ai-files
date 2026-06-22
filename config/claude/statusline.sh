#!/bin/bash
#https://code.claude.com/docs/en/statusline

# Read JSON input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')

# Extract values using jq
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')

# ── Check for repo-memory MCP and get memory count ──
get_repo_memory_stats() {
    local config_files=(
        "$CURRENT_DIR/.claude/config.json"
        "$CURRENT_DIR/.mcp.json"
        "$CURRENT_DIR/mcp.json"
    )
    local memory_count=0
    local memory_display=""

    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ] && jq -e '.mcpServers["repo-memory"]' "$config_file" >/dev/null 2>&1; then
            if command -v repo-memory >/dev/null 2>&1; then
                memory_count=$(repo-memory count 2>/dev/null) || memory_count=0
            else
                local mem_path=$(jq -r '.mcpServers["repo-memory"].env.MCP_MEMORY_SQLITE_PATH // empty' "$config_file" 2>/dev/null)
                if [ -n "$mem_path" ]; then
                    [[ "$mem_path" != /* ]] && mem_path="$CURRENT_DIR/$mem_path"
                    if [ -f "$mem_path" ]; then
                        memory_count=$(sqlite3 "$mem_path" "SELECT COUNT(*) FROM memories" 2>/dev/null) || memory_count=0
                    fi
                fi
            fi
            [ "$memory_count" -gt 0 ] && memory_display=" | 🧠 $memory_count"
            break
        fi
    done

    echo "$memory_display"
}

# ── Z.AI token quota with caching (60s TTL in /dev/shm) ──
get_zai_quota() {
    local cache_file="/dev/shm/zai-quota-cache.json"
    local cache_ttl=60

    # Check if cache is fresh
    local use_cache=false
    if [ -f "$cache_file" ]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        [ "$cache_age" -lt "$cache_ttl" ] && use_cache=true
    fi

    # Fetch fresh data if cache is stale or missing
    if ! $use_cache; then
        local api_key="${ZAI_API_KEY:-$(pass psst/ai/z_ai/api_key 2>/dev/null)}"
        if [ -n "$api_key" ]; then
            curl -s --max-time 3 \
                -H "Authorization: Bearer $api_key" \
                -H "Accept: application/json" \
                "https://api.z.ai/api/monitor/usage/quota/limit" > "${cache_file}.tmp" 2>/dev/null
            if [ -s "${cache_file}.tmp" ]; then
                mv "${cache_file}.tmp" "$cache_file"
            elif [ -f "$cache_file" ]; then
                # curl failed, keep stale cache
                rm -f "${cache_file}.tmp"
            fi
        fi
    fi

    # Parse token quota percentage from cache
    [ ! -f "$cache_file" ] && return

    local percentage reset_ts remaining_ms remaining_min remaining_h remaining_m icon reset_info
    percentage=$(jq -r '.data.limits[] | select(.type == "TOKENS_LIMIT") | .percentage' "$cache_file" 2>/dev/null)
    [ -z "$percentage" ] || [ "$percentage" = "null" ] && return

    reset_ts=$(jq -r '.data.limits[] | select(.type == "TOKENS_LIMIT") | .nextResetTime' "$cache_file" 2>/dev/null)

    # 🔥 icon at 90%+
    if [ "$percentage" -ge 90 ]; then
        icon="🔥"
    else
        icon=""
    fi

    # If at 100%, show time until reset
    if [ "$percentage" -ge 100 ] && [ -n "$reset_ts" ] && [ "$reset_ts" != "null" ]; then
        remaining_ms=$((reset_ts - $(date +%s) * 1000))
        if [ "$remaining_ms" -gt 0 ]; then
            remaining_min=$((remaining_ms / 60000))
            remaining_h=$((remaining_min / 60))
            remaining_m=$((remaining_min % 60))
            if [ "$remaining_h" -gt 0 ]; then
                reset_info=" (resets in ${remaining_h}h${remaining_m}m)"
            else
                reset_info=" (resets in ${remaining_m}m)"
            fi
        fi
    fi

    echo "${icon}${percentage}%${reset_info}"
}

MEMORY_STATS=$(get_repo_memory_stats)
ZAI_QUOTA=$(get_zai_quota)

# Check for active session
SESSION_INFO=""
SESSION_FILE="./.ai-files/sessions/.current-session"
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

echo "🦝 [$MODEL_DISPLAY] 📁 ${CURRENT_DIR##*/}$GIT_BRANCH$MEMORY_STATS$SESSION_INFO | 📊 $ZAI_QUOTA"
