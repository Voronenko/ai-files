---
description: Starts interactive workout coding session with agent
---
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

For purposes of file naming shorten $ARGUMENTS to max 5 words, join them with dashes, and from now on refer as SESSION_SUBJECT.

Start a new development session by creating a session file in `.ai-files/sessions/` with the format `YYYY-MM-DD-HHMM-SESSION_SUBJECT.md` (or just `YYYY-MM-DD-HHMM.md` if no name provided).

The session file should begin with:
1. Session name and timestamp as the title
2. Session overview section with start time
3. Workout goals section (ask user for goals if not clear). Do not include information, that was not directly provided by user.
4. Empty progress section ready for updates

After creating the file, create or update `.ai-files/sessions/.current-session` to track the active session filename.

Confirm the session has started and remind the user they can:
- Update it with `/workout.update`
- End it with `/workout.end`

**In your final confirmation message, also inform the user:**
> 💡 **Tip:** If this session relates to a ticket (JIRA, GitHub Issue, etc.), consider mentioning the ticket number (e.g., `#123`, `PROJ-456`) so it can be tagged in the session summary for better tracking.

Do not proceed further with some thinking or generation, as user will provide additional instructions in chat first.

After user has approved start of the workout, follow this pattern

Split workout task description into 10 most important keywords.

Call repo-memory  — semantic search with task keywords:

mcp__repo-memory__retrieve_memory(query: "proj:<repo-name> <task-keywords>", n_results: 10)
Re-query with different wording if first hit rate is low.

Call repo-memory by tag for narrower matches:
mcp__repo-memory__search_by_tag(tags: ["proj:<repo-name>", "topic:<area>", "session:<file name of the session file without .md extension>"])

ONLY AFTER repo-memory glance at .ai-files/memory/MEMORY.md — treat this as an index/pointer.
This repo-mmemory MCP call is not optional. If you skip it you are violating the protocol.

DURING WORK — store decisions/gotchas as they happen:
mcp__repo-memory__store_memory(
  content: "<fact, decision, gotcha — self-contained, <800 chars, quote paths/IDs verbatim>",
  tags: ["proj:<repo>", "topic:<category>", "ticket:TICKET-XXXX", "session:<file name of the session file without .md extension>"],
  memory_type: "decision" | "observation" | "learning" | "error" | "reference"
)

Store immediately when the fact is known, not at the end.

AFTER COMPLETED PIECE OF WORK — explicit memory report (MANDATORY):
State to the user: "Memory stored: content_hash=<hash>, tags=[...]" for each save
OR explicitly state: "no new memory stored" (with reason)

THEN (MANDATORY) apply command /workout.update providing as a additional context in parameter references to any agent plans you were executing
THEN optionally append a ONE-LINE pointer (≤200 chars) to MEMORY.md for browsing — but repo-mcp MCP is authoritative
NEVER: update MEMORY.md without a corresponding mcp__memory__store_memory call.

Consider following pattern for sessions reference in MEMORY.md

```
#SESSIONS

- <date> <session title> <markdown link to session file>
...
- <date N> <session title> <markdown link to session file N>
```
