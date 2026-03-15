---
name: obsidian
description: allows the agent to search, read, traverse links between notes, and extract tasks, tags, and daily journal information
---

Use the obsidian CLI to retrieve knowledge from an Obsidian vault.
This skill allows the agent to search, read, traverse links between notes,
and extract tasks, tags, and daily journal information.

The agent should treat the vault as a **knowledge graph** where:

* notes = nodes
* links = edges
* tags = metadata
* tasks = actionable items

The goal is to retrieve the most relevant information requested by the user.

---

# When to Use This Skill

Use this skill whenever the user asks about:

* notes stored in Obsidian
* tasks
* tags
* daily journals
* knowledge stored in the vault
* relationships between notes
* documentation or knowledge base items

Examples:

* "Find notes about AWS VPC"
* "What tasks do I have today?"
* "Show today's journal"
* "What notes link to Kubernetes?"
* "List notes in networking folder"
* "What tags exist in my vault?"

---

# Vault Selection

Always run commands using:

obsidian vault=<vault_name>

The vault name must be provided by the calling agent.

---

# Retrieval Strategy

Follow this decision process.

## 1 — Direct Note Access

If the user asks for a specific note:

Examples:

* "Read note WireGuard"
* "Show AWS VPC note"

Run:

obsidian vault=<vault> read file="<note>"

If not found → fallback to search.

---

## 2 — Knowledge Search

If the user asks to find information:

Examples:

* "Find notes about Terraform"
* "Search for WireGuard"

Run:

obsidian vault=<vault> search:context query="<query>" limit=20

This returns relevant lines containing the query.

---

## 3 — Vault Graph Traversal

If the user asks about relationships between notes.

### Backlinks

Example:

"What links to AWS VPC?"

Run:

obsidian vault=<vault>  backlinks file="<note>" format=json

---

### Outgoing Links

Example:

"What does AWS VPC link to?"

Run:

obsidian vault=<vault> links file="<note>"

---

## 4 — Tasks

If the user asks about tasks.

Examples:

* "Show open tasks"
* "Tasks from daily note"
* "What tasks do I have?"

Run:

obsidian vault=<vault> tasks todo format=json

Optional filters:

obsidian vault=<vault> tasks daily
obsidian vault=<vault> tasks file="<note>"

---

## 5 — Daily Journal

If the user refers to today, journal, or daily notes.

Example:

* "Show today's note"
* "What did I write today?"

Run:

obsidian vault=<vault> daily:read

---

## 6 — Tags

If the user asks about tags.

Examples:

* "List tags"
* "What tags exist?"

Run:

obsidian vault=<vault> tags counts format=json

---

## 7 — File Discovery

If the user wants to browse notes.

### List files

obsidian vault=<vault> files 

### List folders

obsidian vault=<vault> folders 

---

# Graph Exploration Strategy

When the user asks a broad question:

Example:

"Tell me what I know about Kubernetes"

Follow this sequence:

1. Search vault
2. Identify key notes
3. Read top notes
4. Collect backlinks
5. Summarize knowledge

Example workflow:

obsidian vault=<vault> search query="kubernetes" limit=10

Then read top results:

obsidian vault=<vault> read file="Kubernetes"

Then expand graph:

obsidian vault=<vault> backlinks file="Kubernetes"

---

# Result Processing

After retrieving results:

1. Extract relevant sections
2. Remove noise
3. Summarize if long
4. Preserve important note titles

Prefer structured output when JSON is returned.

---

# Output Style

When presenting results:

* show note titles
* show key excerpts
* summarize insights

Example:

Result summary:

Relevant notes found:

* Kubernetes Networking
* Kubernetes Security
* Kubernetes Deployment Guide

Key information:

• Kubernetes networking uses CNI plugins
• Common plugins include Calico and Flannel
• Services expose pods internally or externally

---

# Safety Rules

Do NOT modify notes unless explicitly requested.

Allowed operations:

* search
* read
* list
* inspect metadata

Avoid:

* create
* delete
* modify
* rename

unless the user clearly requests it.

---

# Performance Rules

Limit large outputs.

Use:

limit=20

when searching.

Prefer JSON when structured parsing is useful.

---

# Example Command Mapping

User: "Find notes about WireGuard"

obsidian vault=<vault> search:context query="WireGuard" limit=20

---

User: "Read note AWS VPC"

obsidian vault=<vault> read file="AWS VPC"

---

User: "Show tasks"

obsidian vault=<vault> tasks todo format=json

---

User: "Show today's journal"

obsidian vault=<vault> daily:read 
---

User: "What notes link to Terraform?"

obsidian vault=<vault> backlinks file="Terraform" format=json

---

