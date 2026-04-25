# ADR Tools Command Reference

Detailed reference for all adr-tools CLI commands.

## `/adr init [directory]`

Initialize an ADR repository in the current project.

**Parameters:**
- `directory` (optional): Custom directory path for ADRs. Defaults to `doc/adr`

**What it does:**
- Creates the ADR directory
- Creates the first ADR documenting the decision to use ADRs
- Creates a `.adr-dir` file to mark the repository location

**Examples:**
```
/adr init
/adr init documentation/decisions
```

---

## `/adr new <title> [--supersede <n>] [--link <n>:<relation>:<reverse-relation>]`

Create a new Architecture Decision Record.

**Required Parameters:**
- `title`: The title of the decision (will be converted to filename-safe format)

**Optional Parameters:**
- `-s <n>` or `--supersede <n>`: Number of an ADR this decision supersedes
- `-l <n>:<relation>:<reverse-relation>` or `--link <n>:<relation>:<reverse-relation>`: Link to another ADR with custom relation text
  - `n`: Target ADR number
  - `relation`: Link text for new ADR (e.g., "Amends", "Depends on")
  - `reverse-relation`: Link text for target ADR (e.g., "Amended by", "Required by")

**Note:** This command does NOT support a `-d` or `--dir` flag. The ADR directory is automatically discovered via `.adr-dir` file or falls back to `doc/adr`. Use `/adr init <directory>` to set a custom ADR location.

**What it does:**
1. Creates a new numbered ADR file (format: `NNNN-title.md`)
2. Prompts for the following sections:
   - **Context**: The issue motivating this decision
   - **Decision**: The change being proposed or agreed to implement
   - **Consequences**: What becomes easier or more difficult; risks introduced
3. Sets status to "Accepted" by default
4. If superseding, updates both ADRs with appropriate links

**Examples:**
```
/adr new Use PostgreSQL for primary data store
/adr new "Use Redis for caching" --link "1:Depends on:Enables"
/adr new "Migrate to PostgreSQL" --supersede 3
```

---

## `/adr list`

List all Architecture Decision Records in the project.

**What it does:**
- Runs `adr list` to find all ADR files
- Displays a formatted list with number, title, and status

**Example:**
```
/adr list
```

---

## `/adr view <number-or-title>`

View a specific Architecture Decision Record.

**Parameters:**
- `number-or-title` (required): ADR number (e.g., "1") or partial title match

**What it does:**
- Finds the ADR file by number or title search
- Displays the full content of the ADR

**Examples:**
```
/adr view 1
/adr view postgresql
```

---

## ADR File Format

Each ADR follows this structure:

```markdown
# NUMBER. TITLE

Date: YYYY-MM-DD

## Status
Accepted

## Context
The issue motivating this decision, and any context that influences or constrains the decision.

## Decision
The change that we're proposing or have agreed to implement.

## Consequences
What becomes easier or more difficult to do and any risks introduced by the change that will need to be mitigated.
```

---

## ADR Directory Discovery

The skill searches for ADR directories in this order:
1. Looks for `.adr-dir` file (created by `adr init`)
2. Falls back to `doc/adr` directory
3. Searches up the directory tree from the current location

---

## Status Values

- **Accepted**: The current decision
- **Superseded**: Replaced by a newer decision (with link to replacement)
- **Proposed**: Not yet agreed upon by stakeholders

---

## Linking ADRs

ADRs can be linked to show relationships:
- **Supersedes/Superseded by**: Decision replacement
- **Amends/Amended by**: Modification to an existing decision
- **Depends on/Required by**: Dependency between decisions
- **Relates to/Related to**: General reference

---

## Error Messages

- **"ADR directory not found"**: Run `/adr init` first to set up the ADR repository
- **"No ADRs found"**: The repository exists but contains no decisions yet
- **"ADR not found"**: Use `/adr list` to see available ADRs
