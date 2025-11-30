---
description: Starts coding session with agent
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
3. Goals section (ask user for goals if not clear). Do not include information, that was not directly provided by user.
4. Empty progress section ready for updates

After creating the file, create or update `.ai-files/sessions/.current-session` to track the active session filename.

Confirm the session has started and remind the user they can:
- Update it with `/session.update`
- End it with `/session.end`

Do not proceed further with some thinking or generation, as user will provide additional instructions in chat first.
