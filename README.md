# AI Files

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


