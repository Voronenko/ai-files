# DeepSeek + Z.ai Preset (`deepseek-zai`)

`deepseek-zai` runs the Pantheon agents on two personal subscriptions instead
of the default OpenAI setup:

- **Z.ai coding plan** (`zai-coding-plan`) is the primary provider and powers
  the reasoning-heavy roles: Orchestrator, Oracle, and Designer.
- **DeepSeek subscription** (`deepseek`) powers the fast, high-volume roles:
  Librarian, Explorer, Fixer, and the `fast-generic` custom agent.

The `codegraph` MCP (code graph navigation) is backed by graphify, which uses
your **MOONLITE API key**. MOONLITE is configured in your `opencode.json`
provider block, not in the plugin config — the preset only references the
`codegraph` MCP, so it keeps working unchanged.

## Prerequisites

Configure the three providers in `~/.config/opencode/opencode.json`:

| Provider | Purpose |
|---|---|
| `zai-coding-plan` | Z.ai coding plan, GLM-5 models (primary) |
| `deepseek` | DeepSeek subscription, `deepseek-v4-flash` / `deepseek-v4-pro` |
| `moonlite` | API key used by the graphify/`codegraph` MCP server |

Then authenticate and refresh models:

```bash
opencode auth login
opencode models --refresh
```

Model IDs above assume the subscription exposes them under those names. If
your account shows different IDs (e.g. `deepseek-chat`), adjust the
`provider/model` strings to match the `opencode models` output.

## Install the Preset

Drop the config below into `~/.config/opencode/oh-my-opencode-slim.jsonc`
(or merge just the `presets.deepseek-zai` block into an existing config).
With `preset: "deepseek-zai"` set, it becomes active on the next OpenCode
start.

```jsonc
{
  "$schema": "https://unpkg.com/oh-my-opencode-slim@latest/oh-my-opencode-slim.schema.json",
  "preset": "deepseek-zai",
  "showStartupToast": false,
  "companion": {
    "enabled": true,
    "position": "bottom-left",
    "size": "small"
  },
  "presets": {
    "deepseek-zai": {
      "orchestrator": {
        "model": "zai-coding-plan/glm-5",
        "variant": "max",
        "skills": ["*", "!make-interfaces-feel-better"],
        "mcps": ["*", "!context7", "!gh_app"]
      },
      "oracle": {
        "model": "zai-coding-plan/glm-5",
        "variant": "high",
        "skills": ["ce-brainstorm", "workers-best-practices", "web-perf"],
        "mcps": ["codegraph", "searxng", "crawl4ai"]
      },
      "librarian": {
        "model": "deepseek/deepseek-v4-flash",
        "variant": "low",
        "skills": ["customer-research"],
        "mcps": ["context7", "gh_app", "searxng", "crawl4ai"]
      },
      "explorer": {
        "model": "deepseek/deepseek-v4-flash",
        "variant": "low",
        "skills": [],
        "mcps": ["codegraph"]
      },
      "designer": {
        "model": "zai-coding-plan/glm-5",
        "variant": "medium",
        "skills": [
          "make-interfaces-feel-better",
          "better-icons",
          "vue",
          "nuxt",
          "motion",
          "image",
          "marketing-psychology",
          "video"
        ],
        "mcps": ["codegraph"]
      },
      "fixer": {
        "model": "deepseek/deepseek-v4-flash",
        "variant": "high",
        "skills": ["vitest", "pnpm", "vite", "tsdown"],
        "mcps": ["codegraph", "searxng", "crawl4ai"]
      }
    }
  },
  "agents": {
    "fast-generic": {
      "model": "deepseek/deepseek-v4-flash",
      "variant": "low",
      "prompt": "You are a fast generic execution agent for routine mechanical command work. Run requested shell commands, inspect results, and report concise outcomes. For git commits or pushes, inspect git status, git diff, and recent log first; stage only intended files; avoid secrets; preserve repository commit-message style; never amend, rebase, reset --hard, clean, force-push, delete branches, or perform destructive history operations unless the user explicitly requested that exact operation. Do not edit code or make architecture/design decisions.",
      "orchestratorPrompt": "Delegate to @fast-generic for routine mechanical command work: git status/diff/log reconnaissance, normal commit preparation, creating commits, pushing commits, and no-edit command validation such as lint, typecheck, static verification, tests, builds, or package-manager equivalents. Ask it to inspect diffs before committing, stage only intended files, avoid secrets, preserve repository commit-message style, and report final commit hashes or push results. Do not use it for code edits, design work, architecture, debugging strategy, docs research, or destructive git history operations such as amend, rebase, reset --hard, clean, force-push, or deleting branches unless the user explicitly requested that exact operation.",
      "skills": [],
      "mcps": []
    }
  },
  "multiplexer": {
    "type": "tmux",
    "layout": "main-vertical",
    "main_pane_size": 60
  }
}
```

> **Note:** The author's preset used the deprecated top-level `tmux` key,
> which plugin v2.2.x warns about and ignores. This preset uses the
> equivalent modern `multiplexer` block instead, so tmux actually activates.

The same config is available standalone at
[`docs/deepseek-zai-preset.jsonc`](deepseek-zai-preset.jsonc).

## Model Mapping

| Agent | Model | Variant |
|-------|-------|---------|
| Orchestrator | `zai-coding-plan/glm-5` | `max` |
| Oracle | `zai-coding-plan/glm-5` | `high` |
| Designer | `zai-coding-plan/glm-5` | `medium` |
| Librarian | `deepseek/deepseek-v4-flash` | `low` |
| Explorer | `deepseek/deepseek-v4-flash` | `low` |
| Fixer | `deepseek/deepseek-v4-flash` | `high` |
| Fast-generic | `deepseek/deepseek-v4-flash` | `low` |

Z.ai handles the roles that need strong planning, judgment, and visual/UI
taste; DeepSeek handles the broad, high-volume scouting and execution roles.

## Switching at Runtime

If you also keep another preset (for example `openai`) in the same config,
switch from inside OpenCode:

```text
/preset deepseek-zai
```

See [Preset Switching](preset-switching.md) for the full runtime switching
workflow.

## Cost Tuning

- Drop Fixer to `variant: "low"` to cut spend on scoped implementation work.
- Lower the Orchestrator from `max` to `high` (or `medium`) when you want
  faster turnarounds on the Z.ai plan.
- Oracle `high` is a good default; bump to `max` only for hard debugging.

## Skill Reference

`author` means a third-party skill that is not part of the plugin; `public`
means a public tool, framework, or MCP server. Skills are referenced by name;
make sure they are installed in your OpenCode skill directory.

| Skill | Description | Source |
| --- | --- | --- |
| `*` (excl. `!make-interfaces-feel-better`) | All installed skills except those explicitly excluded | `author` |
| `better-icons` | Icon design | `author` |
| `ce-brainstorm` | Brainstorming workflow | `author` |
| `codegraph` | (MCP) code graph navigation — powered by graphify via MOONLITE | `public` |
| `context7` | (MCP) library docs lookup | `public` |
| `crawl4ai` | (MCP) web crawling | `public` |
| `customer-research` | Customer research | `author` |
| `gh_app` | (MCP) GitHub app access | `public` |
| `image` | Image generation/editing | `author` |
| `make-interfaces-feel-better` | UI/UX polish | `author` |
| `marketing-psychology` | Marketing psychology | `author` |
| `motion` | Animation/motion design | `author` |
| `nuxt` | Nuxt framework | `public` |
| `pnpm` | pnpm package manager | `public` |
| `searxng` | (MCP) metasearch engine | `public` |
| `tsdown` | tsdown bundler | `public` |
| `video` | Video generation/editing | `author` |
| `vitest` | Vitest test runner | `public` |
| `vite` | Vite build tool | `public` |
| `vue` | Vue framework | `public` |
| `web-perf` | Web performance optimization | `author` |
| `workers-best-practices` | Worker best practices | `author` |

For the complete configuration reference, see
[Configuration](configuration.md).
