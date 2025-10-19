# AI Files

## Specification toolkits

### Spec-Kit

With uv
```sh
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

With pipx
```sh
pipx install --python "$(pyenv root)/versions/3.11.2/bin/python" git+https://github.com/github/spec-kit.git#egg=specify-cli
```

## Profiles

Naming pattern <scope>-<type>-<provider>

## default-reasoning-openrouter



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
