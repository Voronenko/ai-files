---
description: Ends the workout
---

End the current development session by:

1. Check `.ai-files/sessions/.current-session` for the active session
2. If no active session, use git branch name as SESSION_SUBJECT, creating a session file in `.ai-files/sessions/` with the format `YYYY-MM-DD-HHMM-SESSION_SUBJECT.md` (or just `YYYY-MM-DD-HHMM.md` if no name provided).
3. Append a comprehensive summary including:
   - Session duration
   - Git summary:
     * Total files changed (added/modified/deleted)
     * List all changed files with change type
     * Number of commits made (if any)
     * Final git status
   - Todo summary:
     * Total tasks completed/remaining
     * List all completed tasks
     * List any incomplete tasks with status
   - Key accomplishments
   - All features implemented
   - Problems encountered and solutions
   - Breaking changes or important findings
   - Dependencies added/removed
   - Configuration changes
   - Deployment steps taken
   - Lessons learned
   - What wasn't completed
   - Tips for future developers

4. Extract tracking identifiers:
   - **Ticket number**: Scan session file for ticket references (patterns like `#123`, `PROJ-456`, `JIRA-123`, `ABC-123`) or check if SESSION_SUBJECT contains a ticket. Store without `#` prefix for tag compatibility.
   - **Git branch**: Run `git rev-parse --abbrev-ref HEAD` to get current branch name (strip `origin/` prefix if remote branch)

5. Basing on summary select three tags unique specifically for this session, and add it as #tag1 #tag2 #tag3 to the summary. Include ticket number as a tag if found (e.g., `PROJ-456`, `123`) — omit the `#` prefix for tag storage.

6. Empty the `.ai-files/sessions/.current-session` file (don't remove it, just clear its contents)

7. Inform user the session has been documented

The summary should be thorough enough that another developer (or AI) can understand everything that happened without reading the entire session.

8. Store session metadata in repo-memory using `mcp__repo-memory__memory_store`:
   - **content**: Full session summary with explicit statement of the session file path at the top (format: `## Session File: <path-to-session-md>`)
   - **metadata.tags** (as array): `["session", "mcp-memory-service", "<branch-name>", "<ticket-tag-if-found>", "<tag1>", "<tag2>", "<tag3>", "<primary-subsystem-or-file>"]`
     - Always include `session` and `mcp-memory-service` as first tags
     - Add branch name as tag (e.g., `feature-auth`, `main`, `develop`)
     - Add ticket tag if found (e.g., `PROJ-456`, `123`)
     - Add the three unique tags from step 5
     - Add tags for primary subsystems or key files touched
   - **metadata.type**: "session"

   The session file path MUST be stored both in the content body and as recoverable metadata for future lookup.

9. Ask if user wants to add this session into obsidian, if yes run command

ai-files obsidian-add <path to session markdown file> -t <branch-name>,<ticket-if-found>,tag1,tag2,tag3

where tags include branch, ticket (if found), and the three summary tags

