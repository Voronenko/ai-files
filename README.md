# AI Files

## Dist

The `dist/` folder contains distribution files that will be copied to your code repository. This directory serves as a centralized source for AI Files project configuration, commands, skills, rules, prompts, and plugins that are distributed across different AI development tools.

### Directory Structure

The `dist/` directory organizes files into logical subdirectories aligned with target platforms:

- **`.ai-files/`** - Main AI Files distribution directory
  - `commands/` - Custom commands for session management and memory operations
  - `prompts/` - Prompts and instruction templates
  - `rules/` - Rules for different modes (architect, code, debug)
  - `skills/` - Claude Code skills and templates
  - `plugins/` - Plugin files for various tools

- **Root level files** - `AGENTS.md` and `CLAUDE.md` for agent configuration

### Target Platforms

The distribution is designed to work with multiple AI development platforms:

- **`.kilo/`** - Kilocode configuration and workflows
  - `workflows/` - Kilocode workflow definitions
  - `skills/` - Kilocode skills (shared with Claude)
- **`.claude/`** - Claude Code configuration
  - `commands/` - Claude Code commands (linked from `.ai-files/commands/`)
- **`.roo/`** - Roo Code configuration
  - `commands/` - Roo Code commands (linked from `.ai-files/commands/`)

### Symlink Strategy

The build process uses symlinks to maintain flexibility and avoid duplication:

- **Shared resources**: The `skills/` directory is symlinked to both `.kilo/skills/` and `.claude/skills/` to ensure skills are available to both platforms
- **Platform-specific configs**: Each platform (`.kilo/`, `.claude/`, `.roo/`) gets its own symlink to the `dist/` directory
- **Single source of truth**: The AI Files repository maintains its own `dist/` directory, which is then symlinked by each platform to their respective configuration directories

### Build Process

The Makefile orchestrates distribution build through several targets:

- **`make build`** - Prepares the `dist/` directory by creating necessary subdirectories and copying source files


## ai-files-cli

The `ai-files-cli` is a command-line interface that provides various utilities for managing AI Files project configuration, MCP servers, memory services, and more. It serves as a dispatcher that routes commands to specialized subcommands.

### ai-files-cli mcp

Configure and manage MCP (Model Context Protocol) servers. This utility helps you add, remove, list, and manage MCP server configurations in `~/.kilo/mcp.json`.

**Usage:**
```bash
ai-files-cli mcp <command> [options]
```

**Commands:**

| Command | Description |
|---------|-------------|
| `serve [options] -- <cmd> [args...]` | Start an MCP stdio server with environment variables |
| `add [options] <name> <cmd|url> [...]` | Add MCP server entry with specified transport |
| `remove <name>` | Remove MCP server by name |
| `list` | List all configured MCP servers |
| `get <name>` | Get details about a specific server |
| `add-json <name> <json>` | Add server via raw JSON configuration |
| `help` | Show help message |

**Options for `add` command:**
- `--transport http|sse|stdio` - Specify transport type (required)
- `--env NAME=VALUE` - Add environment variable (can repeat)
- `--` - End of options marker

**Examples:**

Add HTTP transport server:
```bash
ai-files-cli mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

Add SSE transport server:
```bash
ai-files-cli mcp add --transport sse asana https://mcp.asana.com/sse
```

Add stdio transport server with environment variables:
```bash
ai-files-cli mcp add --transport stdio git --env TOKEN=AA -- npx -y git-mcp-server
```

List all configured servers:
```bash
ai-files-cli mcp list
```

Get server details:
```bash
ai-files-cli mcp get git
```

Remove a server:
```bash
ai-files-cli mcp remove git
```

Start MCP server with custom environment:
```bash
ai-files-cli mcp serve --env XYZ=111 -- ./server-binary --stdio
```

### ai-files-cli memory-service

Manage MCP Memory Service for the current project. This utility helps you check memory service status, view statistics, and launch the HTTP UI interface.

**Usage:**
```bash
ai-files-cli memory-service <command>
```

**Commands:**

| Command | Description |
|---------|-------------|
| `status` | Show memory service status and statistics |
| `ui` | Start memory service with HTTP UI interface |
| `help` | Show help message |

**Configuration Search Locations:**
The script searches for memory MCP server configuration in:
- `.claude/config.json`
- `.mcp.json`
- `mcp.json`

**Examples:**

Check memory service status:
```bash
ai-files-cli memory-service status
```

This will display:
- Configuration file location
- Server name
- Total memories count
- Database path
- Memory CLI tool status
- Detailed memory statistics (if CLI tool is available)

Start memory service with HTTP UI:
```bash
ai-files-cli memory-service ui
```

This will:
- Load environment variables from MCP config
- Start the memory server with HTTP interface
- Allow you to interact with the memory service through a web UI

### ai-files-cli obsidian-add

Add a new entry to Obsidian from an existing markdown file with AI Files defaults. This utility automatically adds relevant tags and organizes notes in your Obsidian vault.

**Usage:**
```bash
ai-files-cli obsidian-add [options] <markdown-file>
```

**Environment Variables (defaults):**
- `AI_FILES_VAULT` - Default vault name
- `AI_FILES_VAULT_DEFAULT_PATH` - Default folder path within vault

**Auto-added Tags:**
- `#session` - Added to every note
- `#repo-<repo_name>` - Current git repository name

**Options:**

| Option | Description |
|--------|-------------|
| `-v <vault>` | Target vault name (default: `$AI_FILES_VAULT`) |
| `-p <path>` | Folder path within vault (default: `$AI_FILES_VAULT_DEFAULT_PATH` or git repo name) |
| `-t <tags>` | Additional comma-separated tags (e.g., "work,ideas") |
| `-n <name>` | Note name (defaults to source filename) |
| `-o` | Open note after creating in Obsidian |
| `-h, --help` | Show help message |

**Examples:**

Use environment defaults:
```bash
ai-files-cli obsidian-add ./note.md
```

Override vault:
```bash
ai-files-cli obsidian-add -v KB ./note.md
```

Override path:
```bash
ai-files-cli obsidian-add -p "custom/path" ./note.md
```

Add with extra tags and open in Obsidian:
```bash
ai-files-cli obsidian-add -t "work,ideas" ./note.md -o
```

### ai-files-cli skills-add

Install Claude Code skills from git repositories. This utility discovers, lists, and installs skills to either project-local (`.claude/skills/`) or global (`~/.claude/skills/`) directories.

**Usage:**
```bash
ai-files-cli skills-add <REPO_SOURCE> [OPTIONS]
```

**Arguments:**
- `REPO_SOURCE` - Repository source (URL, shorthand, or path)
  - Examples: `vercel-labs/agent-skills` or `https://github.com/vercel-labs/agent-skills`

**Options:**

| Option | Description |
|--------|-------------|
| `-l, --list` | List available skills without installing |
| `-s, --skill <name>` | Install specific skill(s) (repeatable) |
| `-a, --all` | Install all available skills |
| `-g, --global` | Install to global directory (`~/.claude/skills/`) |
| `-y, --yes` | Skip confirmation prompts (non-interactive mode) |
| `-m, --method <mode>` | Installation method: `symlink` or `copy` (default: symlink) |
| `-h, --help` | Show help message |

**Environment Variables:**
- `INSTALL_INTERNAL_SKILLS` - Include skills marked as internal (default: 0)
- `SKILLS_CLONE_TIMEOUT` - Git clone timeout in seconds (default: 300)

**Examples:**

List available skills:
```bash
ai-files-cli skills-add vercel-labs/agent-skills --list
```

Install specific skill:
```bash
ai-files-cli skills-add vercel-labs/agent-skills --skill frontend-design
```

Install multiple skills:
```bash
ai-files-cli skills-add vercel-labs/agent-skills --skill frontend-design --skill skill-creator
```

Install all skills globally:
```bash
ai-files-cli skills-add vercel-labs/agent-skills --all --global
```

Non-interactive installation (CI/CD):
```bash
ai-files-cli skills-add vercel-labs/agent-skills --skill frontend-design --yes
```

Install using copy method instead of symlink:
```bash
ai-files-cli skills-add vercel-labs/agent-skills --skill frontend-design --method copy
```

### ai-files-cli setup-worktree

Set up ai-files symlinks in git worktrees. This utility automatically configures AI coding agent symlinks and configuration files when working with git worktrees, ensuring each worktree has access to the main repository's AI files configuration.

**Usage:**
```bash
ai-files-cli setup-worktree
```

**Prerequisites:**
- Must be run from within a git worktree (not the main repository)
- The main repository must have `.ai-files/` directory

**What it does:**
1. **Detects worktree environment** - Verifies the command is running from within a git worktree
2. **Finds main repository** - Locates the main ai-files repository using `git rev-parse --git-common-dir`
3. **Creates `.ai-files` symlink** - Links worktree's `.ai-files` → main repository's `.ai-files`
4. **Copies agent symlinks** - Replicates symlinks for `.claude`, `.kilo`, `.roo`, `.specify` if they exist in the main repository root
5. **Copies `.mcp.json`** - Copies MCP configuration from main repository if it exists

**Examples:**

Create a worktree and set it up:
```bash
# Create a new worktree
git worktree add ../my-project-feature -b feature/new-feature

# Navigate to the worktree
cd ../my-project-feature

# Run the setup script
ai-files-cli setup-worktree
```

**Output example:**
```
✅ Running within git worktree: /path/to/worktree
ℹ️  Finding main ai-files repository...
✅ Found main repository: /path/to/main/repo
ℹ️  Creating .ai-files symlink...
✅ .ai-files linked -> /path/to/main/repo/.ai-files
✅ .claude linked -> .ai-files/dotclaude
✅ .kilo linked -> .ai-files/dotkilo
✅ .mcp.json copied

📋 Summary:
   • .ai-files linked to /path/to/main/repo/.ai-files
   • Agent symlinks copied from main repository
   • .mcp.json copied
```

**Notes:**
- If symlinks or files already exist, the script skips them with a warning
- Existing `.ai-files` symlink will be replaced if found
- The script exits with an error if `.ai-files` exists but is not a symlink
- Run this script once per worktree after creating it

### ai-files-cli update

Update `.ai-files/`, `.claude/`, `.kilo/`, `.roo/` directories from `dist/`. This utility handles recursive copying of files and folders, preserves relative symlinks, detects locally modified files, and provides interactive confirmation with diff view.

**Usage:**
```bash
ai-files-cli update [OPTIONS]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-s, --source DIR` | Source directory (default: `./dist`) |
| `-y, --yes` | Automatically overwrite all modified files |
| `-n, --no` | Skip all modified files (no overwrite) |
| `--dry-run` | Show what would be done without making changes |
| `-v, --verbose` | Enable verbose output |
| `-h, --help` | Show help message |

**Features:**
- Preserves relative symlinks
- Detects locally modified files and asks for confirmation with diff
- Tracks and reports copied, deleted, and skipped files
- Shows detailed summary of all changes

**Examples:**

Interactive update (asks for each modified file):
```bash
ai-files-cli update
```

Auto-overwrite all changes:
```bash
ai-files-cli update -y
```

Skip all local changes:
```bash
ai-files-cli update -n
```

Preview changes only (dry run):
```bash
ai-files-cli update --dry-run
```

Verbose output with detailed file operations:
```bash
ai-files-cli update -v
```

Update from custom source directory:
```bash
ai-files-cli update -s /path/to/custom/dist
```

### ai-files-cli version

Show version information for the ai-files project. The version is derived from git tags, branch names, or commit hashes.

**Usage:**
```bash
ai-files-cli version
```

**Version Detection Logic:**
1. If on a git tag, returns the tag name
2. If not on a tag, returns `branch-commit_hash` format
3. In detached HEAD state, returns `detached-commit_hash`
4. If not in a git repository, returns `unknown`

**Examples:**

```bash
ai-files-cli version
# Output: v1.2.3 (if on tag)
# Output: main-abc1234 (if on branch)
# Output: detached-abc1234 (if detached HEAD)
# Output: unknown (if not in git repo)
```

## Commands

AI Files provides a comprehensive set of commands for managing development sessions, code reviews, memory operations, and more. These commands help streamline your workflow and maintain context across development sessions.

### pr-review

Conducts a comprehensive code review of a specific Pull Request using git worktree isolation and Pragmatic Quality framework. This command creates an isolated worktree environment for reviewing PRs without contaminating your main working directory, then analyzes changes, checks project guidelines, and generates a structured review report with critical issues, important suggestions, and positive observations. The review is automatically posted as a comment on the GitHub PR after your approval.

### resolve-merge-conflicts

Resolves merge conflicts after a git merge operation by analyzing conflicting files and helping you decide between keeping your changes, keeping their changes, or creating a careful combination of both. The command searches for all conflict markers, presents each conflict with context, and when you're confident about the resolution, edits the file to remove conflict markers and saves the desired final state without staging the resolved files.

### workout.start

Starts a new development session by creating a session file in `.ai-files/sessions/` with format `YYYY-MM-DD-HHMM-SESSION_SUBJECT.md` and tracking the active session in `.ai-files/sessions/.current-session`. The session file includes session name, timestamp, overview section, and workout goals section (asking you for goals if not clear), then confirms the session has started and reminds you of available update and end commands.

### workout.update

Updates the current development session by appending a timestamped entry with your notes or a summary of recent activities, including git status summary showing files added/modified/deleted and current branch, plus todo list status showing completed/in-progress/pending tasks. The update captures any issues encountered, solutions implemented, and code changes made, keeping the session comprehensive for future reference while remaining concise.

### workout.end

Ends the current development session by creating a comprehensive summary including session duration, git summary with total files changed and list of all changed files, number of commits made, and final git status, plus todo summary showing total tasks completed/remaining and lists of completed and incomplete tasks. The summary also includes key accomplishments, all features implemented, problems encountered and solutions, breaking changes or important findings, dependencies added/removed, configuration changes, deployment steps taken, lessons learned, what wasn't completed, and tips for future developers, then empties the `.current-session` file.

### workout.current

Shows the current session status by checking if `.ai-files/sessions/.current-session` exists, and if no active session is found, informs you and suggests starting one. If an active session exists, it displays the session name and filename, calculates and shows duration since start, shows the last few updates, displays current workout goals/tasks, and reminds you of available commands, keeping the output concise and informative.

### workout.list

Lists all development sessions by checking if `.ai-files/sessions/` directory exists, then listing all `.md` files (excluding hidden files and `.current-session`) and for each session file showing the filename, extracting and displaying the session title, showing the date/time, and displaying the first few lines of overview if available. The results are sorted by most recent first, and if `.ai-files/sessions/.current-goal` exists, it highlights which session is currently active, presenting everything in a clean, readable format.

### workout.help

Shows help for the session management system, displaying available commands including `/workout.start [name]` to start a new session with optional name, `/workout.update [notes]` to add notes to current session, `/workout.end` to end session with comprehensive summary, `/workout.list` to list all session files, `/workout.current` to show current session status, and `/workout.help` to show this help. It also explains how sessions work (markdown files in `.ai-files/sessions/` with `YYYY-MM-DD-HHMM-name.md` format, only one session active at a time, tracking progress, issues, solutions, and learnings), provides best practices (start session when beginning significant work, update regularly with important changes or findings, end with thorough summary for future reference, review past sessions before starting similar work), and shows an example workflow.

### mcp-memory-server

A suite of commands for managing the MCP Memory Service, providing comprehensive memory storage, retrieval, and management capabilities for maintaining context across development sessions.

#### memory-context

Captures current conversation and project context as a memory that can be recalled later, perfect for preserving important session insights, decisions, and progress summaries. The command analyzes the current conversation to extract key insights, decisions, and progress made, captures current project state including working directory and git repository status, recent file changes and commits, and current branch and development context, then creates a concise summary of the session including main topics discussed, decisions made or problems solved, action items or next steps identified, and code changes or configurations applied, with automatic smart tagging based on session content and project context including machine hostname as a source identifier.

#### memory-health

Checks the health and status of your MCP Memory Service, providing detailed diagnostics and statistics about your memory storage and service connectivity. The command locates your MCP Memory Service using mDNS auto-discovery or configured endpoints, verifies that the service is running and accessible from Claude Code, checks database health, memory statistics, and service performance, provides insights about your stored memories, database size, and usage patterns, and if issues are found, provides specific recommendations for resolution with common issues checked including service not running, port conflicts, database corruption, permission issues, and model loading, plus auto-fix capabilities including restart service, clear cache, repair database, and update configuration.

#### memory-ingest-dir

Batch ingests all supported documents from a directory into the MCP Memory Service database, scanning the directory for supported file types (PDF, TXT, MD, JSON), applying filtering based on file extensions and max files limit, validating that the service is running and accessible, then uploading files in batch using the documents API endpoint. All documents are processed with consistent tagging and chunking parameters, files are processed in parallel for efficiency, progress is displayed with file counts and chunk statistics, each document gets processed independently so failures in one don't stop others, and large directories may take time so consider using `--max-files` for testing.

#### memory-ingest

Ingests a single document file into the MCP Memory Service database, validating that the file exists and checking if it's a supported format (PDF, TXT, MD, JSON), determining the service endpoint (trying localhost:8080, then 8443), then uploading the document using the documents API endpoint with your specified parameters and monitoring progress. The document will be automatically parsed and chunked for optimal retrieval, each chunk becomes a separate memory entry with semantic embeddings, progress will be displayed during ingestion, and failed chunks will be reported but won't stop the overall process.

#### memory-recall

Retrieves memories from your MCP Memory Service using natural language time expressions and contextual queries, excelling at finding past conversations, decisions, and notes based on when they occurred. The command parses natural language time queries like "yesterday", "last week", "two months ago", "last Tuesday", "this morning", "last summer", or "before the database migration", considers current project context to find relevant memories related to your current work, automatically filters results to show most relevant memories first considering temporal relevance to your query, project and directory context matching, and semantic similarity to current work, then formats retrieved memories with clear context about when they were created and why they're relevant.

#### memory-search

Searches through your stored memories using tags, content keywords, and semantic similarity, perfect for finding specific information across all your stored memories regardless of when they were created. The command performs tag-based search supporting both exact and partial tag matching, content search using semantic search across memory content using the same embedding model used for storage, supports complex searches combining tags, content, and metadata filters, ranks results by relevance considering both semantic similarity and tag match strength, and highlights how found memories relate to your current project and session.

#### memory-store

Stores information in your MCP Memory Service with proper context and tagging, capturing current session context and storing it as a persistent memory that can be recalled later. The command analyzes the current working directory, recent files, and conversation context to understand what you're working on, takes the provided information or current session summary and prepares it for storage, automatically generates relevant tags based on machine hostname (source identifier), current project directory name, programming languages detected, file types and patterns, and any explicit tags you provide, then includes useful metadata like machine hostname for source tracking, timestamp and session context, project path and git repository info, and file associations and dependencies, using a hybrid remote-first approach with local fallback for reliability.

#### session-start

Displays session memory context by running the session-start memory awareness hook manually to show relevant memories, project context, and git analysis, specifically designed as a Windows workaround for SessionStart hook bug (#160). On Windows, SessionStart hooks cause Claude Code to hang indefinitely, so this slash command provides the same functionality but can be triggered manually when you start a new session, working on all platforms (Windows, macOS, Linux), and is recommended to use at the start of each coding session, when switching projects or contexts, after compacting conversations to refresh memory context, or when you need to see what memories are available.

## Specification toolkits

### BMAD Method CLI

A command-line tool for applying the BMAD (Behavior, Model, Action, Data) method to structure and guide software development.

#### Installation

##### Global Installation
```bash
npm install -g bmad-method
```

##### Local Installation
```bash
npx bmad-method install
```

##### Usage
```bash
bmad-method <command>
```

##### Commands

| Command | Description |
| --- | --- |
| `init` | Initialize a new project with the BMAD method |
| `generate` | Generate a new component based on the BMAD method |
| `lint` | Lint a component based on the BMAD method |

### Speckit

Spec Kit enables **Spec-Driven Development**—a methodology where executable specifications drive the creation of working software. It integrates with AI coding agents to guide development through structured prompts and workflows.

#### Installation

Using `pipx` (Recommended)

Ensure you have Python 3.11+ and `pipx` installed, then run:

```bash
pipx install --python "$(pyenv which python)" "git+https://github.com/github/spec-kit.git#egg=specify-cli"
```

Alternative: Using uv (from official docs)

```sh
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

#### Usage

Check system requirements:
```sh
specify check
```

Initialize a new project:
```sh
specify init my-project
```

Features

| Command               | Description                     |
|-----------------------|---------------------------------|
| /speckit.constitution | Define project principles       |
| /speckit.specify      | Describe what to build          |
| /speckit.plan         | Choose your tech stack          |
| /speckit.tasks        | Generate implementation tasks   |
| /speckit.implement    | Auto-generate code              |

Works with AI agents: Claude, Copilot, Cursor, Gemini, Qwen, Windsurf, and more.


### OpenSpec

OpenSpec is a specification framework that enables AI-assisted, contract-first development. It helps teams define, validate, and implement APIs and system behaviors using structured, human-readable specs.

#### Installation

Global Installation

```bash
npm install -g @fission-ai/openspec@latest
```

Local Installation
```bash
npx @fission-ai/openspec@latest install
```

#### Usage

Common workflows include:

- Generating client/server stubs from OpenAPI or custom spec formats
- Validating spec consistency
- Integrating with AI development agents for spec-driven coding

```bash
openspec <command>
```

Commands
| Command | Description |
| --- | --- |
| `init` | Initialize a new project with the OpenSpec method |
| `generate` | Generate a new component based on the OpenSpec method |
| `lint` | Lint a component based on the OpenSpec method |




## Roocode

Roocode is a powerful code generation tool that allows you to create code from a set of instructions.


## Profiles

Naming pattern <scope>-<type>-<provider>

# default-reasoning-openrouter



## How Instructions are Combined[​](https://docs.roocode.com/features/custom-instructions?_highlight=rules#how-instructions-are-combined "Direct link to How Instructions are Combined")

Instructions are placed in the system prompt in this exact format:

```txt
====
USER'S CUSTOM INSTRUCTIONS

The following additional instructions are provided by the user, and should be followed to the best of your ability without interfering with the TOOL USE guidelines.

[Language Preference (if set)]

[Global Instructions (from Prompts Tab)]

[Mode-specific Instructions (from Prompts Tab for the current mode)]

Global Rules (from ~/.roo/):
[Contents of files in ~/.roo/rules-{modeSlug}/ (if directory exists and is not empty)]
[Contents of files in ~/.roo/rules/ (if directory exists and is not empty)]

Mode-Specific Instructions (from Files/Directories):
[Contents of files in .roo/rules-{modeSlug}/ (if directory exists and is not empty)]
[Contents of .roorules-{modeSlug} file (if .roo/rules-{modeSlug}/ does not exist or is empty, and file exists)]

Workspace-Wide Instructions (from Files/Directories):
[Contents of files in .roo/rules/ (if directory exists and is not empty)]
[Contents of .roorules file (if .roo/rules/ does not exist or is empty, and file exists)]

====
```

_Note: Global rules load first, followed by workspace rules that can override them. Mode-specific rules appear before general rules within each level, and directory-based rules take precedence over file-based fallbacks._

* * *

## Rules about .rules files[​](https://docs.roocode.com/features/custom-instructions?_highlight=rules#rules-about-rules-files "Direct link to Rules about .rules files")

-   **File Location:** The preferred method uses directories within `.roo/` (`.roo/rules/` and `.roo/rules-{modeSlug}/`). The fallback method uses single files (`.roorules` and `.roorules-{modeSlug}`) located directly in the workspace root.
-   **Empty Files:** Empty or missing rule files are silently skipped
-   **Source Headers:** Each rule file's contents are included with a header indicating its source
-   **Rule Interaction:** Mode-specific rules complement global rules rather than replacing them

* * *

## Examples of Custom Instructions[​](https://docs.roocode.com/features/custom-instructions?_highlight=rules#examples-of-custom-instructions "Direct link to Examples of Custom Instructions")

-   "Always use spaces for indentation, with a width of 4 spaces"
-   "Use camelCase for variable names"
-   "Write unit tests for all new functions"
-   "Explain your reasoning before providing code"
-   "Focus on code readability and maintainability"
-   "Prioritize using the most common library in the community"
-   "When adding new features to websites, ensure they are responsive and accessible"

Pro Tip: Team Standardization

For team environments, consider these approaches:

**Project Standards**: Use workspace `.roo/rules/` directories under version control to standardize Roo's behavior for specific projects. This ensures consistent code style and development workflows across team members.

**Organization Standards**: Use global rules (`~/.roo/rules/`) to establish organization-wide coding standards that apply to all projects. Team members can set up identical global rules for consistency across all work.

**Hybrid Approach**: Combine global rules for organization standards with project-specific workspace rules for project-specific requirements. Workspace rules can override global rules when needed.

The directory-based approach offers better organization than single `.roorules` files and supports both global and project-level customization.


## MCP servers

```json
  {
    "mcpServers": {
      "memory": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-memory"]
      },
      "playwright": {
        "command": "npx",
        "args": ["-y", "@playwright/mcp@latest"]
      },
      "ssh": {
        "command": "npx",
        "args": ["-y", "@iflow-mcp/ssh-mcp-server"]
      },
      "browsermcp": {
        "command": "npx",
        "args": ["-y", "@anthropic/mcp-server-browserbase@latest"],
        "env": {
          "BROWSERBASE_API_KEY": "<YOUR_BROWSERBASE_API_KEY>",
          "BROWSERBASE_PROJECT_ID": "<YOUR_BROWSERBASE_PROJECT_ID>"
        }
      },
      "atlassian": {
        "command": "npx",
        "args": ["-y", "@anthropic/mcp-server-atlassian@latest"],
        "env": {
          "ATLASSIAN_CLIENT_ID": "<YOUR_ATLASSIAN_CLIENT_ID>",
          "ATLASSIAN_CLIENT_SECRET": "<YOUR_ATLASSIAN_CLIENT_SECRET>",
          "ATLASSIAN_CALLBACK_PORT": "48923"
        }
      },
      "slack": {
        "command": "npx",
        "args": ["-y", "@anthropic/mcp-server-slack@latest"],
        "env": {
          "SLACK_BOT_TOKEN": "<YOUR_SLACK_BOT_TOKEN>",
          "SLACK_TEAM_ID": "<YOUR_SLACK_TEAM_ID>"
        }
      },
      "circleci": {
        "command": "npx",
        "args": ["-y", "@anthropic/mcp-server-circleci@latest"],
        "env": {
          "CIRCLECI_TOKEN": "<YOUR_CIRCLECI_TOKEN>",
          "CIRCLECI_BASE_URL": "https://circleci.com"
        }
      }
    }
  }
```

  Де взяти credentials:

  | Сервіс      | Де отримати                                                            |
  |-------------|------------------------------------------------------------------------|
  | Browserbase | https://browserbase.com → Dashboard → API Keys                         |
  | Atlassian   | https://developer.atlassian.com/console/myapps/ → Create OAuth 2.0 app |
  | Slack       | https://api.slack.com/apps → Create App → OAuth & Permissions          |
  | CircleCI    | https://app.circleci.com → User Settings → Personal API Tokens         |


## mcp-memory-server organization


```
project/
├── .claude/
│   ├── settings.json        ← MCP HERE (only here)
│   └── settings.local.json  ← permissions/statusLine HERE
├── .ai-files/
│   └── memory.db
```

install mcp-memory-server to claude

```sh
claude mcp add repo-memory --scope project --env MCP_MEMORY_SQLITE_PATH=.ai-files/memory.db --env MCP_MEMORY_STORAGE_BACKEND=sqlite_vec --env PYTHONUNBUFFERED=1 -- memory server
```

which corresponds to `.mcp.json`:

```json
{
  "mcpServers": {
    "memory": {
      "command": "memory",
      "args": [
        "server"
      ],
      "env": {
        "MCP_MEMORY_SQLITE_PATH": ".ai-files/memory.db",
        "MCP_MEMORY_STORAGE_BACKEND": "sqlite_vec",
        "PYTHONUNBUFFERED": "1"
      }
    }
  }
}
```

to see dashboard, option also would be
```
{
  "mcpServers": {
    "repo-memory": {
      "transport": "streamablehttp",
      "url": "http://your-server:8000/mcp",
      "headers": {
        "Authorization": "Bearer your-secure-api-key"
      }
    }
  }
}
```

```sh
# Generate a secure API key
export MCP_API_KEY=$(openssl rand -hex 32)

# Configure HTTPS (recommended for production)
export MCP_HTTPS_ENABLED=true
export MCP_SSL_CERT_FILE=/path/to/cert.pem
export MCP_SSL_KEY_FILE=/path/to/key.pem
```

https://github.com/doobidoo/mcp-memory-service/blob/main/docs/integration/multi-client.md

## 3rd party work and ideas used

### claude sessions
  - https://github.com/iannuttall/claude-sessions/
  - see video https://www.youtube.com/watch?v=higAxJk_zig

## Dist

The `dist/` folder contains the distribution files that will be copied to your code repository. This directory serves as a centralized source for AI Files project configuration, commands, skills, rules, prompts, and plugins that are distributed across different AI development tools.

### Directory Structure

The `dist/` directory organizes files into logical subdirectories aligned with the target platforms:

- **`.ai-files/`** - Main AI Files distribution directory
  - `commands/` - Custom commands for session management and memory operations
  - `prompts/` - Prompts and instruction templates
  - `rules/` - Rules for different modes (architect, code, debug)
  - `skills/` - Claude Code skills and templates
  - `plugins/` - Plugin files for various tools
- **Root level files** - `AGENTS.md` and `CLAUDE.md` for agent configuration

### Target Platforms

The distribution is designed to work with multiple AI development platforms:

- **`.kilo/`** - Kilocode configuration and workflows
  - `workflows/` - Kilocode workflow definitions
  - `skills/` - Kilocode skills (shared with Claude)
- **`.claude/`** - Claude Code configuration
  - `commands/` - Claude Code commands (linked from .ai-files/commands/)
- **`.roo/`** - Roo Code configuration
  - `commands/` - Roo Code commands (linked from .ai-files/commands/)

### Symlink Strategy

The build process uses symlinks to maintain flexibility and avoid duplication:

- **Shared resources**: The `skills/` directory is symlinked to both `.kilo/skills/` and `.claude/skills/` to ensure skills are available to both platforms
- **Platform-specific configs**: Each platform (`.kilo/`, `.claude/`, `.roo/`) gets its own symlink to the `dist/` directory
- **Single source of truth**: The AI Files repository maintains its own `dist/` directory, which is then symlinked by each platform to their respective configuration directories

### Build Process

The Makefile orchestrates the distribution build through several targets:

- **`make build`** - Prepares the `dist/` directory by creating necessary subdirectories and copying source files
- **`make prepare-dist`** - Copies and organizes all source files into the `dist/` directory structure
- **`make relink-from-dist`** - Creates symlinks from `dist/` to platform-specific directories (`.kilo/`, `.claude/`, `.roo/`)
- **`make prepare-claude`** - Sets up Claude Code specific commands by linking from `.ai-files/commands/`
- **`make publish-spec-kit`** - Downloads and integrates Spec Kit templates for all platforms
- **`make publish-memory-bank`** - Publishes memory bank instructions to all agent directories

### Installation

To install the AI Files distribution to your code repository:

```bash
# Build the distribution
make build

# Link to your platform (choose one)
make relink-from-dist  # For Kilocode
# OR
make link-roo          # For Roo Code
# OR
make link-claude        # For Claude Code
```

This setup ensures that each AI development tool has access to the appropriate configuration files, commands, and resources while maintaining a clean separation between the AI Files repository and the platform-specific configurations.


