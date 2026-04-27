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

4. Basing on summary select three tags unique specifically for this session, and add it as #tag1 #tag2 #tag3 to the summary

5. Empty the `.ai-files/sessions/.current-session` file (don't remove it, just clear its contents)

6. Inform user the session has been documented

The summary should be thorough enough that another developer (or AI) can understand everything that happened without reading the entire session.

7.  Add with repo-memory information mcp summary about this session with path to session file, tag it additionally with session tag, consider also tags to refer primary subsystems or main filenames touched in the session tags, plus three tags you consider useful.

8. Ask if user wants to add this session into obsidian, if yes run command

ai-files obsidian-add <path to session markdown file> -t tag1,tag2,tag3

where tag1 tag2 and tag3 are tags from summary

