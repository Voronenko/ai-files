# 4. Use .worktreeinclude for Claude Code worktree compatibility

Date: 2026-04-26

## Status

Accepted

## Context

Claude Code uses git worktrees to isolate feature work. Git worktrees are fresh checkouts that don't include untracked files from the main repository, such as `.env`, `.env.local`, or other local configuration files. This creates a problem when Claude creates worktrees for development:

- AI coding tools need access to environment configuration
- Local secrets and API keys are typically gitignored
- Without these files, worktrees are non-functional
- Manual copying is error-prone and forgettable

We need an automated way to populate worktrees with necessary untracked files while ensuring tracked files are never duplicated.

## Decision

We will use a `.worktreeinclude` file in the repository root to track files that must be populated to new worktrees for Claude Code compatibility.

**How it works:**
- `.worktreeinclude` uses `.gitignore` syntax to list file patterns
- Only gitignored files matching patterns are copied (tracked files never duplicated)
- The `ai-files-cli worktree` command automatically processes `.worktreeinclude`
- When Claude creates a worktree, the setup script copies matching files

**Example `.worktreeinclude`:**
```
# Environment files
.env
.env.local
.env.*.local

# Secret configurations
config/secrets.json
*.key
*.pem

# Local overrides
config/local.*
```

**Implementation:**
- The `bin/ai-files-cli-worktree` script already includes this functionality
- `expand_worktree_patterns()` function processes glob patterns
- Interactive prompts handle file conflicts during setup
- Candidates are suggested based on gitignored files

## Consequences

**Benefits:**
- Worktrees are immediately functional after creation
- No manual file copying required
- Consistent environment across all worktrees
- Tracked files are protected from duplication
- Pattern-based approach handles various file types

**Risks:**
- Sensitive files copied to worktrees must be protected (same as main repo)
- `.worktreeinclude` must be kept in sync with actual needs
- Large files may slow down worktree creation

**Mitigations:**
- `.worktreeinclude` should only include necessary configuration
- Use specific patterns rather than broad wildcards
- Review `.worktreeinclude` in PRs to prevent bloating
- Document what each pattern is for in comments
