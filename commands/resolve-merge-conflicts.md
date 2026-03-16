---
allowed-tools: Grep, LS, Read, Edit, MultiEdit, Write, NotebookEdit, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, ListMcpResourcesTool, ReadMcpResourceTool, mcp__context7__resolve-library-id, mcp__context7__get-library-docs, mcp__playwright__browser_close, mcp__playwright__browser_resize, mcp__playwright__browser_console_messages, mcp__playwright__browser_handle_dialog, mcp__playwright__browser_evaluate, mcp__playwright__browser_file_upload, mcp__playwright__browser_install, mcp__playwright__browser_press_key, mcp__playwright__browser_type, mcp__playwright__browser_navigate, mcp__playwright__browser_navigate_back, mcp__playwright__browser_navigate_forward, mcp__playwright__browser_network_requests, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_click, mcp__playwright__browser_drag, mcp__playwright__browser_hover, mcp__playwright__browser_select_option, mcp__playwright__browser_tab_list, mcp__playwright__browser_tab_new, mcp__playwright__browser_tab_select, mcp__playwright__browser_tab_close, mcp__playwright__browser_wait_for, Bash, Glob
description: Resolve the conflicts after the merge, explain decision
---
# Resolve Merge Conflicts

Your job is to resolve merge conflicts in the current branch of the current repo.

- [1. Preparation](#1-preparation)
- [2. Build context](#2-build-context)
- [3. Resolve conflicts](#3-resolve-conflicts)
- [Very Important: Don't be afraid to ask for help](#very-important-dont-be-afraid-to-ask-for-help)

## User Input

```text
$ARGUMENTS
```

## 1. Preparation

Assume I already ran:

\`\`\`bash
git checkout <branch I merge from>
git pull
git checkout <current_branch>
git merge <branch I merge from>
\`\`\`

If this command is being invoked, there are unresolved merge conflicts you need to fix.

## 2. Build context

1. Run `git diff <branch I merge from>` to understand the changes in this branch relative to `<branch I merge from>`.
2. Run `rg "<<<<<<<"` to find all merge conflicts.

## 3. Resolve conflicts

For each conflict, decide whether to:

1. Keep **our** changes (the current branch)
2. Keep **their** changes (`main`)
3. Use a careful, intelligent combination of both

In most cases you should aim for (3), but correctness matters more than cleverness.

When you are confident about how to resolve a conflict:

1. Edit the file to the desired final state
2. Remove all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
3. Save the file and run any relevant checks or tests if practical
4. Do not stage the resolved files with `git add`, but inform me so I can perform  this action

## Very Important: Don't be afraid to ask for help

If you are not sure how a conflict should be resolved, stop and ask me for direction or clarification.

1. Show me the conflicting chunks
2. Explain what you believe you should do
3. Wait for confirmation

Now go resolve the conflicts.
