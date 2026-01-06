#!/usr/bin/env bash
set -e

COMMAND="~/ai-files/mcp/github/github-mcp-wrapper"
ARG1="stdio"

if [ "$1" = "user" ]; then
    CONFIG_FILE="${USER_CONFIG_FILE:-$HOME/.config/VSCodium/User/globalStorage/kilocode.kilo-code/settings/mcp_settings.json}"
elif [ "$1" = "local" ]; then
    CONFIG_FILE="${LOCAL_CONFIG_FILE:-.kilocode/mcp.json}"
else
    echo "Usage: $0 [user|local]"
    exit 1
fi

# Create the configuration using jq
if [ -f "$CONFIG_FILE" ]; then
    jq --arg command "$COMMAND" --arg arg1 "$ARG1" \
      '.mcpServers.github = {command: $command, args: [$arg1]}' \
      "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
else
    echo '{}' | jq --arg command "$COMMAND" --arg arg1 "$ARG1" \
      '.mcpServers.github = {command: $command, args: [$arg1]}' \
      > "$CONFIG_FILE"
fi

echo "Configuration updated successfully for $1"
