# Store Memory with Context

I'll help you store information in your MCP Memory Service with proper context and tagging. This command captures the current session context and stores it as a persistent memory that can be recalled later.

## What I'll do:

1. **Detect Current Context**: I'll analyze the current working directory, recent files, and conversation context to understand what we're working on.

2. **Capture Memory Content**: I'll take the provided information or current session summary and prepare it for storage.

3. **Add Smart Tags**: I'll automatically generate relevant tags based on:
   - Machine hostname (source identifier)
   - Current project directory name
   - Programming languages detected
   - File types and patterns
   - Any explicit tags you provide

4. **Store with Metadata**: I'll include useful metadata like:
   - Machine hostname for source tracking
   - Timestamp and session context
   - Project path and git repository info
   - File associations and dependencies

## Usage Examples:

```bash
claude /memory-store "We decided to use SQLite-vec instead of ChromaDB for better performance"
claude /memory-store --tags "decision,architecture" "Database backend choice rationale"
claude /memory-store --type "note" "Remember to update the Docker configuration after the database change"
```

## Implementation:

I'll use a **layered storage approach**: the local `repo-memory` MCP server is the source of truth, and the remote HTTP API is used only as a fallback when MCP is unavailable.

### Primary: MCP Protocol (`repo-memory` server)
- **Try MCP first**: Call the `repo-memory` MCP server (configured in `.mcp.json` — stdio, SQLite-vec backend at `.ai-files/memory.db`) using its `memory_store` tool. **Tags MUST go inside `metadata`** — there is no top-level `tags` parameter (verified against the server's `tools/list`):
  ```python
  mcp__repo-memory__memory_store(
      content="<memory content>",
      metadata={"tags": "mcp-memory-service,<project-name>,<additional-tags>"}
  )
  ```
  - ⚠️ **Correct shape**: `metadata={"tags": "comma,separated,string"}`. Passing `tags` at the top level silently saves an **untagged** memory and violates the tagging directive.
- **Fast & local**: No network round-trip; the memory is immediately retrievable in the same session via `mcp__repo-memory__memory_search(query=...)` (semantic search). Tag-based deletion uses `mcp__repo-memory__memory_delete(tags=[...])`.
- **Project tagging (mandatory)**: Per `directives/memory-tagging.md`, I ALWAYS pass `mcp-memory-service` as the **first** tag so session-start hooks and tag-based searches can find the memory.

### If MCP Is Not Available — Inform the User First
- **Detect the failure**: If the `repo-memory` MCP server is not registered or not running (no `mcp__repo-memory__*` tools are available in the current session, or a call errors out), I will **stop and inform the user** before doing anything else, for example:
  > ⚠️ The `repo-memory` MCP server is unavailable in this session. I'll fall back to the remote HTTP API unless you'd rather fix MCP first.
  >
  > To enable local MCP storage:
  > - The server is declared in **`zcode.json`** (ZCode-native: `mcp.servers[]` with `env:[{name,value}]`). **Note**: ZCode does *not* read `.mcp.json` or `opencode.json` for session MCP servers — those are for other agents.
  > - MCP servers connect at **session startup** (`mcp.startup`), so after editing `zcode.json` you must **start a new session** for `repo-memory` to appear.
  > - Verify the server itself works any time with: `memory server` (runs cleanly in stdio; `memory --version` → 10.73.0).
- I will **not silently fall through** — the user must know that local MCP storage failed and why, so the decision to use the remote fallback is explicit.

### Fallback: Remote HTTP API
- **Only after informing the user**: `POST https://narrowbox.local:8443/api/memories`
- **Real-time sync**: Changes immediately available across all clients
- **Single source of truth**: Consolidated database on the remote server
- **Local staging**: If the remote is also unreachable, stage locally for later sync

### Smart Sync Workflow
```
1. Try repo-memory MCP tool first (fastest, local, no network)
2. If MCP unavailable: STOP → inform the user and explain how to start it
3. Only then: fall back to remote HTTP API (https://narrowbox.local:8443/api/memories)
4. If remote also fails: stage locally + notify user
5. On reconnect: ./sync/memory_sync.sh automatically syncs
6. Conflict resolution: Remote wins, with user notification
```

The content will be stored with automatic context detection:
- **Machine Context**: Hostname automatically added as tag (e.g., "source:your-machine-name")
- **Project Context**: Current directory, git repository, recent commits
- **Session Context**: Current conversation topics and decisions
- **Technical Context**: Programming language, frameworks, and tools in use
- **Temporal Context**: Date, time, and relationship to recent activities

### Service Endpoints:
- **Primary (MCP)**: `repo-memory` MCP server — `mcp__repo-memory__memory_store(content=..., metadata={"tags": ...})` (see `.mcp.json`)
- **Fallback (HTTP)**: `https://narrowbox.local:8443/api/memories` — only after informing the user that MCP is unavailable
- **Sync Status**: Use `./sync/memory_sync.sh status` to check pending changes
- **Manual Sync**: Use `./sync/memory_sync.sh sync` for full synchronization

For MCP storage I use the `repo-memory` tool directly with a JSON `metadata.tags` string. For the HTTP fallback I use curl with the `-k` flag for HTTPS, proper JSON payload formatting, and automatic client hostname detection via the `X-Client-Hostname` header.

## Arguments:

- `$ARGUMENTS` - The content to store as memory, or additional flags:
  - `--tags "tag1,tag2"` - Explicit tags to add
  - `--type "note|decision|task|reference"` - Memory type classification
  - `--project "name"` - Override project name detection
  - `--private` - Mark as private/sensitive content

I'll store the memory automatically without asking for confirmation. The memory will be saved immediately using proper JSON formatting with the curl command. You'll receive a brief confirmation showing the content hash and applied tags after successful storage.