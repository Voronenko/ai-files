SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

magic: clean build dist
	echo magic done

clean:
	# Remove old build
	rm -rf ./dist/
	# Ensure target directories exist
	mkdir -p ./dist/.ai-files
	mkdir -p ./dist/.ai-files/skills/
	mkdir -p ./dist/.ai-files/commands/
	mkdir -p ./dist/.ai-files/dotkilo/commands
	# claude supports resolving symlinks, only one source
	mkdir -p ./dist/.ai-files/dotclaude/commands
	# opencode support
	mkdir -p ./dist/.ai-files/dotopencode/commands
	# agents support
	mkdir -p ./dist/.ai-files/dotagents/commands
	# Create empty skills directories (will be populated with individual symlinks later)
	# dotclaude/skills is populated by publish-spec-kit-claude
	mkdir -p dist/.ai-files/dotkilo/skills
	mkdir -p dist/.ai-files/dotclaude/skills
	mkdir -p dist/.ai-files/dotopencode/skills
	mkdir -p dist/.ai-files/dotagents/skills
	# create symlinks from hidden names to visible directories (relative symlinks)
	ln -sfn .ai-files/dotkilo dist/.kilo
	ln -sfn .ai-files/dotclaude dist/.claude
	ln -sfn .ai-files/dotspecify dist/.specify
	ln -sfn .ai-files/dotopencode dist/.opencode
	ln -sfn .ai-files/dotagents dist/.agents
	# ai-files repo uses own dist
	ln -sfn dist/.kilo .kilo
	ln -sfn dist/.claude   .claude
	ln -sfn dist/.opencode .opencode
	ln -sfn dist/.agents .agents
relink-from-dist:
	# create symlinks from hidden names to visible directories (relative symlinks)
	ln -sfn .ai-files/dotkilo dist/.kilo
	ln -sfn .ai-files/dotclaude dist/.claude
	ln -sfn .ai-files/dotspecify dist/.specify
	ln -sfn .ai-files/dotopencode dist/.opencode
	ln -sfn .ai-files/dotagents dist/.agents
	# ai-files repo uses own dist
	ln -sfn dist/.kilo .kilo
	ln -sfn dist/.claude   .claude
	ln -sfn dist/.opencode .opencode
	ln -sfn dist/.agents .agents


prepare-dist: publish-spec-kit publish-commands publish-memory-bank publish-prompts
	mkdir -p ./dist/.ai-files
	cp -r plugins ./dist/.ai-files/
	@echo "Copying and linking plugin files..."
        # unified stub for AGENTS.md
	cp AGENTS.md ./dist/
	# redirector for claude code to use AGENTS.md
	cp CLAUDE.md ./dist/
	# instructions for more efficient tools using
	cp COMMON_CODE_TASKS.md ./dist/.ai-files/
	# clause specific configs
	cp -r config/claude/* ./dist/.ai-files/dotclaude/
	# opencode specific configs
	@if [ -d "config/opencode" ]; then \
		cp -r config/opencode/* ./dist/.ai-files/dotopencode/; \
	fi
	# agents specific configs
	@if [ -d "config/agents" ]; then \
		cp -r config/agents/* ./dist/.ai-files/dotagents/; \
	fi
	cp -r rules ./dist/.ai-files/
	# unified skills
	cp -r skills ./dist/.ai-files/
	# vendor skills
	if [ -d vendor/skills ]; then \
		cp -r vendor/skills/* ./dist/.ai-files/skills/; \
	fi
	# vendor agents
	if [ -d vendor/agents ]; then \
		mkdir -p ./dist/.ai-files/agents && \
		cp -r vendor/agents/* ./dist/.ai-files/agents/; \
	fi
	# Makefile for dist operations
	cp Makefile.dist ./dist/Makefile
	# gitignore for dist
	cp dotignore.local.dist ./dist/dotignore.local
	# roaming files list for worktree setup
	@echo "Creating roaming-files.txt..."
	@echo ".mcp.json" > ./dist/.ai-files/roaming-files.txt
	@echo "AGENTS.md" >> ./dist/.ai-files/roaming-files.txt
	@echo "CLAUDE.md" >> ./dist/.ai-files/roaming-files.txt
	# Build metadata: git snapshot + dist creation timestamp (read by `ai-files --version`)
	@echo "Generating .ai-files/VERSION ..."
	@printf 'VERSION=%s\nCOMMIT=%s\nBRANCH=%s\nBUILD_DATE=%s\n' \
		"$$(git describe --tags --always --dirty 2>/dev/null || echo unknown)" \
		"$$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)" \
		"$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)" \
		"$$(date -u +%Y-%m-%dT%H:%M:%SZ)" > ./dist/.ai-files/VERSION

prepare-claude:
	@mkdir -p ./dist/.ai-files/dotclaude/commands
	@find ./dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.ai-files/dotclaude/commands/$$(basename "$$f")"; \
		done \
	' sh {} +
	@echo "✅ Created symlinks to ./dist/.ai-files/dotclaude/commands/"
	# speckit commands are available as a skills
	@find ./dist/.ai-files/dotclaude/commands -type l -name 'speckit*.md' -delete
	@echo "✅ Removed speckit command symlinks (available as skills)"

build: prepare-dist prepare-claude _link-dot-dir-skills create-default-symlinks
	echo build completed

# Helper: Read default skills from YAML, output space-separated list
# Entries are bare names for own skills, namespace/skill for vendored ones
get-default-skills:
	@if [ ! -f "default_skills.yaml" ]; then \
		echo "" >&2; \
		exit 1; \
	fi
	@if command -v yq >/dev/null 2>&1; then \
		yq eval '.default_skills[]' default_skills.yaml 2>/dev/null | tr '\n' ' ' | sed 's/ *$$//'; \
	else \
		grep -E '^\s+-\s+[a-zA-Z0-9_/.-]+' default_skills.yaml 2>/dev/null | \
			sed 's/^\s*-\s*//' | tr '\n' ' ' | sed 's/ *$$//'; \
	fi

# Shared skill resolver: turns default_skills.yaml entries into link:src pairs.
#   bare 'foo'   -> 'foo:foo'      (own skill, keeps bare name)
#   'ns/foo'     -> 'foo:ns/foo', or 'foo-ns:ns/foo' when the bare name collides
# Collisions are computed over the full inventory (own depth-1 + vendor depth-2
# dirs containing SKILL.md), so link names never depend on which entries are listed.
define RESOLVE_SKILLS
resolve_skills() { \
	local root="$$1"; \
	local colliding; \
	colliding=$$(cd "$$root" && find . -mindepth 2 -maxdepth 3 -name SKILL.md \
		| sed 's|^\./||; s|/SKILL.md$$||' | awk -F/ '{print $$NF}' | sort | uniq -d); \
	for e in $$2; do \
		case "$$e" in \
			*/*) ns="$${e%%/*}"; name="$${e##*/}";; \
			*) ns=""; name="$$e";; \
		esac; \
		link="$$name"; \
		if [ -n "$$ns" ] && echo "$$colliding" | grep -qx "$$name"; then \
			link="$$name-$$ns"; \
		fi; \
		if [ -e "$$root/$$e" ]; then echo "$$link:$$e"; fi; \
	done; \
}
all_skill_entries() { \
	cd "$$1" && find . -mindepth 2 -maxdepth 3 -name SKILL.md \
		| sed 's|^\./||; s|/SKILL.md$$||'; \
}
endef
export RESOLVE_SKILLS

# Populate dotkilo/skills/, dotopencode/skills/ and dotagents/skills/ with individual symlinks
# to dist/.ai-files/skills/ (own skills and vendored ns/skill), filtered by default_skills.yaml
_link-dot-dir-skills:
	@echo "Linking skills to dotkilo/skills/, dotopencode/skills/ and dotagents/skills/..."
	@eval "$$RESOLVE_SKILLS"; \
	DEFAULT_SKILLS=$$(make --no-print-directory get-default-skills 2>/dev/null); \
	if [ -z "$$DEFAULT_SKILLS" ]; then \
		echo "  ⚠️  No default_skills.yaml, using all skills"; \
		DEFAULT_SKILLS=$$(all_skill_entries dist/.ai-files/skills); \
	fi; \
	for pair in $$(resolve_skills dist/.ai-files/skills "$$DEFAULT_SKILLS"); do \
		link="$${pair%%:*}"; src="$${pair#*:}"; \
		for dir in dotkilo dotopencode dotagents; do \
			ln -sfr "dist/.ai-files/skills/$$src" "dist/.ai-files/$$dir/skills/$$link" 2>/dev/null; \
		done; \
	done; \
	echo "  ✅ dot dirs skills populated"

# Create symlinks with default skills filter
# Runs create-symlinks first, then removes skills not in default_skills.yaml
create-default-symlinks:
	@echo "Creating symlinks with default skills filter..."
	@$(MAKE) --no-print-directory create-symlinks
	@echo "Filtering to default skills only..."
	@DEFAULT_SKILLS=$$(make --no-print-directory get-default-skills 2>/dev/null); \
	if [ -z "$$DEFAULT_SKILLS" ]; then \
		echo "  ⚠️  No default skills configured, keeping all skills"; \
	else \
		echo "  Keeping: $$DEFAULT_SKILLS"; \
		KEEP=$$(eval "$$RESOLVE_SKILLS"; \
			resolve_skills dist/.ai-files/skills "$$DEFAULT_SKILLS" | cut -d: -f1); \
		for d in dist/.claude/skills dist/.kilo/skills dist/.opencode/skills dist/.agents/skills; do \
			cd "$$d" && \
			for item in *; do \
				if [ "$$item" != "*" ] && [ -e "$$item" ]; then \
					if ! echo "$$KEEP" | grep -qx "$$item"; then \
						rm -rf "$$item" 2>/dev/null; \
					fi; \
				fi; \
			done; \
			cd - >/dev/null; \
		done; \
		echo "  ✅ Filtered to default skills"; \
	fi

create-symlinks:
	@echo "Creating .claude/, .kilo/, .opencode, and .agents directories with symlinks..."
	# Create directories (remove symlinks if they exist)
	@if [ -L "dist/.claude" ]; then rm "dist/.claude"; fi
	@if [ -L "dist/.kilo" ]; then rm "dist/.kilo"; fi
	@if [ -L "dist/.specify" ]; then rm "dist/.specify"; fi
	@if [ -L "dist/.opencode" ]; then rm "dist/.opencode"; fi
	@if [ -L "dist/.agents" ]; then rm "dist/.agents"; fi
	@mkdir -p dist/.claude/commands dist/.claude/skills dist/.claude/agents
	@mkdir -p dist/.kilo/commands dist/.kilo/skills dist/.kilo/agents dist/.kilo/rules
	@mkdir -p dist/.opencode/commands dist/.opencode/skills dist/.opencode/agents dist/.opencode/rules
	@mkdir -p dist/.agents/commands dist/.agents/skills dist/.agents/agents dist/.agents/rules
	# Create file-level symlinks for .claude/commands/
	@find dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.claude/commands/$$base"; \
		done \
	' sh {} +
	# Link ALL skills (own + vendored ns/skill with conflict suffixes) into every
	# agent skills dir; create-default-symlinks trims this to the default list
	@eval "$$RESOLVE_SKILLS"; \
	for pair in $$(resolve_skills dist/.ai-files/skills "$$(all_skill_entries dist/.ai-files/skills)"); do \
		link="$${pair%%:*}"; src="$${pair#*:}"; \
		for d in dist/.claude/skills dist/.kilo/skills dist/.opencode/skills dist/.agents/skills; do \
			ln -sfr "dist/.ai-files/skills/$$src" "$$d/$$link"; \
		done; \
	done
	# Same for .kilo/
	@find dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.kilo/commands/$$base"; \
		done \
	' sh {} +
	# Create file-level symlinks for .kilo/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type f -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.kilo/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	# Create dir-level symlinks for .kilo/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type d -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.kilo/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	@find dist/.ai-files/rules -mindepth 1 -maxdepth 1 -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.kilo/rules/$$base"; \
		done \
	' sh {} +
	# Link everything from dist/.ai-files/dotclaude/ to dist/.claude/ (except commands and hooks, handled separately)
	# settings.local.json is copied (not symlinked) so it stays a self-contained, locally-editable file
	@if [ -d "dist/.ai-files/dotclaude" ]; then \
		find dist/.ai-files/dotclaude -mindepth 1 -maxdepth 1 ! -name "commands" ! -name "hooks" ! -name "settings.local.json" -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				if [ -L "dist/.claude/$$base" ]; then \
					rm "dist/.claude/$$base"; \
				fi; \
				ln -sfr "$$f" "dist/.claude/$$base"; \
			done \
		' sh {} +; \
	fi
	@rm -f dist/.claude/settings.local.json
	@cp -f dist/.ai-files/dotclaude/settings.local.json dist/.claude/settings.local.json
	# Link individual files from hooks/ directory
	@if [ -d "dist/.ai-files/dotclaude/hooks" ]; then \
		mkdir -p dist/.claude/hooks; \
		find dist/.ai-files/dotclaude/hooks -mindepth 1 -maxdepth 1 -type f -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.claude/hooks/$$base"; \
			done \
		' sh {} +; \
	fi
	# Link everything from dist/.ai-files/dotclaude/skills/ to dist/.claude/skills/
	@if [ -d "dist/.ai-files/dotclaude/skills" ]; then \
		find dist/.ai-files/dotclaude/skills -mindepth 1 -maxdepth 1 -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				if [ -e "dist/.claude/skills/$$base" ]; then \
					rm -rf "dist/.claude/skills/$$base"; \
				fi; \
				ln -sfr "$$f" "dist/.claude/skills/$$base"; \
			done \
		' sh {} +; \
	fi
	# Create file-level symlinks for .claude/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type f -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.claude/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	# Create dir-level symlinks for .claude/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type d -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.claude/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	# Same for .opencode/
	@find dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.opencode/commands/$$base"; \
		done \
	' sh {} +
	# Create file-level symlinks for .opencode/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type f -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.opencode/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	# Create dir-level symlinks for .opencode/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type d -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.opencode/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	@find dist/.ai-files/rules -mindepth 1 -maxdepth 1 -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.opencode/rules/$$base"; \
		done \
	' sh {} +
	# Link everything from dist/.ai-files/dotopencode/ to dist/.opencode/
	@if [ -d "dist/.ai-files/dotopencode" ]; then \
		find dist/.ai-files/dotopencode -mindepth 1 -maxdepth 1 ! -name "skills" ! -name "commands" ! -name "rules" ! -name "agents" -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfn "$$f" "dist/.opencode/$$base"; \
			done \
		' sh {} +; \
	fi
	# Same for .agents/
	@find dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.agents/commands/$$base"; \
		done \
	' sh {} +
	# Create file-level symlinks for .agents/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type f -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.agents/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	# Create dir-level symlinks for .agents/agents/
	@if [ -d "dist/.ai-files/agents" ]; then \
		find dist/.ai-files/agents -mindepth 1 -maxdepth 1 -type d -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfr "$$f" "dist/.agents/agents/$$base"; \
			done \
		' sh {} +; \
	fi
	@find dist/.ai-files/rules -mindepth 1 -maxdepth 1 -exec sh -c '\
		for f do \
			base=$$(basename "$$f"); \
			ln -sfr "$$f" "dist/.agents/rules/$$base"; \
		done \
	' sh {} +
	# Link everything from dist/.ai-files/dotagents/ to dist/.agents/
	@if [ -d "dist/.ai-files/dotagents" ]; then \
		find dist/.ai-files/dotagents -mindepth 1 -maxdepth 1 ! -name "skills" ! -name "commands" ! -name "rules" ! -name "agents" -exec sh -c '\
			for f do \
				base=$$(basename "$$f"); \
				ln -sfn "$$f" "dist/.agents/$$base"; \
			done \
		' sh {} +; \
	fi
	@ln -sfn dist/.kilo .kilo
	@ln -sfn dist/.claude .claude
	@ln -sfn dist/.opencode .opencode
	@ln -sfn dist/.agents .agents
	@ln -sfn dist/.specify .specify
	# Recreate dist/.specify symlink (removed at start of create-symlinks)
	@ln -sfn .ai-files/dotspecify dist/.specify
	@echo "✅ Symlinks created"

publish-prompts:
	mkdir -p ./dist/.ai-files/prompts
	cp -r ./prompts/ ./dist/.ai-files


adr-toc: adr-graph
	adr generate toc > ./docs/architecture/decisions/README.md
	@echo "## Architecture Decision Graph\n\n![Architecture Decision Graph](graph.svg)\n" >> ./docs/architecture/decisions/README.md
adr-graph:
	adr generate graph > ./docs/architecture/decisions/graph.dot
	dot -Tsvg ./docs/architecture/decisions/graph.dot -o ./docs/architecture/decisions/graph.svg

publish-spec-kit-kilo:
	@echo "Creating symlinks for kilocode commands..."
	@mkdir -p ./dist/.ai-files/dotkilo/commands; \
	find ./dist/.ai-files/commands/speckit -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.ai-files/dotkilo/commands/$$(basename "$$f")"; \
		done \
	' sh {} +; \
	echo "✅ Successfully created symlinks to ./dist/.ai-files/dotkilo/commands/"

publish-commands-kilo:
	@echo "Creating symlinks for non-speckit commands to kilocode..."
	@mkdir -p ./dist/.ai-files/dotkilo/commands; \
	find ./dist/.ai-files/commands -maxdepth 1 -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.ai-files/dotkilo/commands/$$(basename "$$f")"; \
		done \
	' sh {} +; \
	echo "✅ Successfully created symlinks to ./dist/.ai-files/dotkilo/commands/"

publish-spec-kit-claude:
	@echo "Initializing claude skills using specify CLI..."
	@TEMP_DIR=$$(mktemp -d); \
	echo "Created temporary directory: $$TEMP_DIR"; \
	cd "$$TEMP_DIR" && \
	specify init . --ai claude --script sh; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to run specify init"; \
		rm -rf "$$TEMP_DIR"; \
		exit 1; \
	fi; \
	cd - >/dev/null; \
	echo "Preparing destination..."; \
	mkdir -p ./dist/.ai-files/dotclaude; \
	if [ -L ./dist/.ai-files/dotclaude/skills ]; then \
		echo "Removing existing skills symlink..."; \
		rm ./dist/.ai-files/dotclaude/skills; \
	fi; \
	if [ -d ./dist/.ai-files/dotclaude/skills ]; then \
		echo "Removing existing skills directory..."; \
		rm -rf ./dist/.ai-files/dotclaude/skills; \
	fi; \
	echo "Copying .claude/skills/ to ./dist/.ai-files/dotclaude/skills/..."; \
	cp -r "$$TEMP_DIR/.claude/skills" ./dist/.ai-files/dotclaude/skills; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to copy skills directory"; \
		rm -rf "$$TEMP_DIR"; \
		exit 1; \
	fi; \
	rm -rf "$$TEMP_DIR"; \
	echo "✅ Successfully initialized .claude/skills/ templates to ./dist/.ai-files/dotclaude/skills/"

publish-spec-kit: publish-spec-kit-templates publish-spec-kit-kilo publish-spec-kit-claude
	@echo ""
	@echo "🎉 All spec-kit templates have been successfully processed!"
	@echo "📦 Summary:"
	@echo "   • .kilo/ commands linked to ./dist/.ai-files/dotkilo/"
	@echo "   • .claude/ skills initialized to ./dist/.ai-files/dotclaude/"
	@echo "   • .specify/ templates initialized to ./dist/.ai-files/dotspecify/"
	@echo ""
	@echo "✨ All spec-kit templates are now ready for use!"

publish-commands-source:
	@echo "Copying commands source to dist..."
	@mkdir -p ./dist/.ai-files
	@cp -r commands ./dist/.ai-files/
	@chmod +x ./dist/.ai-files/dotspecify/scripts/bash/*.sh
	@echo "✅ Commands source copied to ./dist/.ai-files/commands/"

publish-commands: publish-commands-source publish-commands-kilo
	@echo ""
	@echo "🎉 All non-speckit commands have been successfully linked!"
	@echo "📦 Summary:"
	@echo "   • workout commands linked to ./dist/.ai-files/dotkilo/commands/"
	@echo "   • pr-review, resolve-merge-conflicts also linked"
	@echo ""
	@echo "✨ All agents now have access to workout and other custom commands!"

upgrade-spec-kit-cli:
	pipx upgrade specify-cli

publish-spec-kit-templates:
	@echo "Initializing spec-kit templates using specify CLI..."
	@TEMP_DIR=$$(mktemp -d); \
	echo "Created temporary directory: $$TEMP_DIR"; \
	cd "$$TEMP_DIR" && \
	specify init . --ai generic --ai-commands-dir=.ai-files/commands --script sh; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to run specify init"; \
		rm -rf "$$TEMP_DIR"; \
		exit 1; \
	fi; \
	cd - >/dev/null; \
	echo "Preparing destination..."; \
	mkdir -p ./dist/.ai-files; \
	if [ -L ./dist/.ai-files/dotspecify ]; then \
		echo "Removing existing dotspecify symlink..."; \
		rm ./dist/.ai-files/dotspecify; \
	fi; \
	if [ -d ./dist/.ai-files/dotspecify ]; then \
		echo "Removing existing dotspecify directory..."; \
		rm -rf ./dist/.ai-files/dotspecify; \
	fi; \
	echo "Copying .specify/ to ./dist/.ai-files/dotspecify/..."; \
	cp -r "$$TEMP_DIR/.specify" ./dist/.ai-files/dotspecify; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to copy .specify directory"; \
		rm -rf "$$TEMP_DIR"; \
		exit 1; \
	fi; \
	mkdir -p ./dist/.ai-files/commands/speckit; \
	cp -r $$TEMP_DIR/.ai-files/commands/* ./dist/.ai-files/commands/speckit/; \
	rm -rf "$$TEMP_DIR"; \
	echo "✅ Successfully initialized .specify/ templates to ./dist/.ai-files/dotspecify/"

update-memory-bank:
	@echo "Downloading memory bank from kilo.ai..."
	@mkdir -p rules
	@curl -s -o "prompts/memory-bank-instructions.md" "https://kilo.ai/docs/downloads/memory-bank.md"
	@if [ $$? -ne 0 ]; then \
		echo "Error: Failed to download memory bank file"; \
		exit 1; \
	fi
	@echo "Processing memory bank file..."
	@sed -i 's/\.kilo\/rules\//\.ai-files\//g' "prompts/memory-bank-instructions.md"
	@sed -i 's/Kilo Code/AI FILES/g' "prompts/memory-bank-instructions.md"
	@echo "✅ Memory bank successfully downloaded and updated to prompts/memory-bank-instructions.md"

publish-memory-bank:
	@echo "Publishing memory bank instructions to all agents..."
	@if [ ! -f "prompts/memory-bank-instructions.md" ]; then \
		echo "Error: Memory bank file not found. Run 'make update-memory-bank' first."; \
		exit 1; \
	fi
	@echo "Creating memory bank directories for each agent..."
	@mkdir -p ./dist/.ai-files/dotkilo/rules/memory-bank
	@mkdir -p ./dist/.ai-files/dotopencode/rules/memory-bank
	@mkdir -p ./dist/.ai-files/dotagents/rules/memory-bank
	@echo "Copying memory bank instructions to agent directories..."
	@cp "prompts/memory-bank-instructions.md" "./dist/.ai-files/dotkilo/rules/memory-bank/"
	@cp "prompts/memory-bank-instructions.md" "./dist/.ai-files/dotopencode/rules/memory-bank/"
	@cp "prompts/memory-bank-instructions.md" "./dist/.ai-files/dotagents/rules/memory-bank/"
	@echo "✅ Memory bank successfully published to all agent directories:"
	@echo "   • ./dist/.ai-files/dotkilo/rules/memory-bank/"
	@echo "   • ./dist/.ai-files/dotopencode/rules/memory-bank/"
	@echo "   • ./dist/.ai-files/dotagents/rules/memory-bank/"


## Common tools installation routines

install-graphify:
	pipx install graphifyy
	pipx inject graphifyy openai
	pipx inject graphifyy tree-sitter-hcl

install-spec-bmad:
	npm install -g bmad-method
install-spec-bmad-local:
	npx bmad-method install
install-spec-kit:
	pipx install --python "$(shell pyenv which python)" git+https://github.com/github/spec-kit.git#egg=specify-cli
install-spec-openspec:
	npm install -g @fission-ai/openspec@latest
install-spec-openspec-local:
	npx @fission-ai/openspec install
install-mermaid-cli:
	npm install -g @mermaid-js/mermaid-cli

# @BIN="$(HOME)/dotfiles/bin/claude"; \

install-cli-claude-code:
	@BIN="$(HOME)/.local/bin/claude"; \
	DL="$(HOME)/.claude/downloads"; \
	GCS="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"; \
	mkdir -p "$$(dirname $$BIN)" "$$DL"; \
	\
	case "$$(uname -s)" in \
		Darwin) OS=darwin ;; \
		Linux) OS=linux ;; \
	esac; \
	case "$$(uname -m)" in \
		x86_64|amd64) ARCH=x64 ;; \
		arm64|aarch64) ARCH=arm64 ;; \
	esac; \
	if [ "$$OS" = linux ] && ldd /bin/ls 2>&1 | grep -q musl; then \
		PLATFORM="linux-$${ARCH}-musl"; \
	else \
		PLATFORM="$${OS}-$${ARCH}"; \
	fi; \
	\
	VERSION="$$(curl -fsSL $$GCS/latest)"; \
	MANIFEST="$$(curl -fsSL $$GCS/$$VERSION/manifest.json)"; \
	CHECKSUM="$$(echo "$$MANIFEST" | jq -r '.platforms["'$$PLATFORM'"].checksum')"; \
	TMP="$$DL/claude-$$VERSION-$$PLATFORM"; \
	\
	curl -fsSL "$$GCS/$$VERSION/$$PLATFORM/claude" -o "$$TMP"; \
	if [ "$$OS" = darwin ]; then \
		echo "$$CHECKSUM  $$TMP" | shasum -a 256 -c -; \
	else \
		echo "$$CHECKSUM  $$TMP" | sha256sum -c -; \
	fi; \
	chmod +x "$$TMP"; \
	mv "$$TMP" "$$BIN"; \
	\
	"$$BIN" install $(TARGET); \
	echo "✅ Claude installed at $$BIN"

install-cli-aider:
	pipx install aider-chat[all] --python $(shell which python)
	pipx inject aider-chat google-generativeai
	echo "Use cli command aider"
	echo "Refer: obsidian://open?vault=KB&file=pages%2FDEVELOPMENT%2FAI-WORKPLACE%2Fai-workpace-aider"
install-cli-taskmaster:
	npm install -g task-master-ai
	echo "Use task-master init on a new project"

# LEGACY 1.x — APT package (superseded by portable 2.0 tar.gz). Kept for reference.
# install-antigravity-apt:
# 	sudo mkdir -p /etc/apt/keyrings
# 	curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
# 		sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
# 	echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
# 		sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
# 	sudo apt update
# 	sudo apt install antigravity

# ── Antigravity 2.0 (portable tar.gz) ────────────────────────────────────────
# Upstream: https://storage.googleapis.com/antigravity-public/antigravity-hub/<ver>/linux-x64/Antigravity.tar.gz
# Bundle: Antigravity-x64/antigravity (ELF 197M), chrome-sandbox, locales/, resources/app.asar (icon at /icon.png 512×512)
# Installs to ~/apps/Antigravity2 (strip-components), exposes ~/.local/bin/antigravity2 + Desktop + applications launchers.
ANTIGRAVITY2_VERSION ?= 2.10.0-4996573600546816
ANTIGRAVITY2_URL ?= https://storage.googleapis.com/antigravity-public/antigravity-hub/$(ANTIGRAVITY2_VERSION)/linux-x64/Antigravity.tar.gz
ANTIGRAVITY2_DEST ?= $(HOME)/apps/Antigravity2
ANTIGRAVITY2_TMP ?= /tmp/antigravity2.tar.gz

install-antigravity2:
	@set -euo pipefail; \
	URL="$(ANTIGRAVITY2_URL)"; DEST="$(ANTIGRAVITY2_DEST)"; TMP="$(ANTIGRAVITY2_TMP)"; \
	LEGACY_DEST="$$HOME/Apps/Antigravity2"; DESKTOP_DIR="$$(xdg-user-dir DESKTOP 2>/dev/null || echo "$$HOME/Desktop")"; \
	if [ -d "$$LEGACY_DEST" ] && [ ! -d "$$DEST" ] && [ "$$LEGACY_DEST" != "$$DEST" ]; then echo "↪ Migrating legacy $$LEGACY_DEST → $$DEST"; mkdir -p "$$(dirname "$$DEST")"; mv "$$LEGACY_DEST" "$$DEST" 2>/dev/null || cp -a "$$LEGACY_DEST" "$$DEST"; fi; \
	echo "⬇️  Antigravity 2.0 ($$(basename $$URL)) → $$DEST"; \
	mkdir -p "$$DEST" "$$HOME/.local/bin" "$$HOME/.local/share/applications" "$$HOME/.local/share/icons" "$$DESKTOP_DIR"; \
	if [ -f "$$HOME/Downloads/Antigravity.tar.gz" ] && [ "$$URL" = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.10.0-4996573600546816/linux-x64/Antigravity.tar.gz" ]; then \
		echo "   Using cached ~/Downloads/Antigravity.tar.gz (override with ANTIGRAVITY2_URL=… or rm the file)"; \
		cp "$$HOME/Downloads/Antigravity.tar.gz" "$$TMP"; \
	else \
		echo "   Downloading $$URL"; \
		curl -fsSL "$$URL" -o "$$TMP"; \
	fi; \
	echo "   Extracting → $$DEST (strip top-level Antigravity-x64/)"; \
	tar -xzf "$$TMP" -C "$$DEST" --strip-components=1; \
	chmod +x "$$DEST/antigravity"; \
	if [ -f "$$DEST/chrome-sandbox" ]; then \
		if sudo -n true 2>/dev/null; then \
			sudo chown root:root "$$DEST/chrome-sandbox" 2>/dev/null || true; \
			sudo chmod 4755 "$$DEST/chrome-sandbox" 2>/dev/null || chmod 4755 "$$DEST/chrome-sandbox" || chmod 0755 "$$DEST/chrome-sandbox"; \
		else \
			chmod 4755 "$$DEST/chrome-sandbox" 2>/dev/null || chmod 0755 "$$DEST/chrome-sandbox"; \
		fi; \
	fi; \
	echo "   Extracting icon from resources/app.asar"; \
	ICON_DST="$$DEST/icon.png"; ICON_SHARE="$$HOME/.local/share/icons/antigravity2.png"; ICON_SRC=""; \
	if [ -f "$$DEST/resources/app.asar" ]; then \
		ASAR_TMP="$$(mktemp -d)"; \
		if command -v npx >/dev/null 2>&1 && npx --yes @electron/asar extract "$$DEST/resources/app.asar" "$$ASAR_TMP" >/dev/null 2>&1 && [ -f "$$ASAR_TMP/icon.png" ]; then \
			cp "$$ASAR_TMP/icon.png" "$$ICON_DST"; ICON_SRC="$$ICON_DST"; \
		else \
			echo "   ⚠️  asar extract failed — trying pixmap fallback"; \
			if [ -f "/usr/share/pixmaps/antigravity.png" ]; then cp "/usr/share/pixmaps/antigravity.png" "$$ICON_DST" && ICON_SRC="$$ICON_DST"; fi; \
		fi; \
		rm -rf "$$ASAR_TMP"; \
		if [ -n "$$ICON_SRC" ] && [ -f "$$ICON_SRC" ]; then cp -f "$$ICON_SRC" "$$ICON_SHARE" 2>/dev/null || true; fi; \
	fi; \
	if [ ! -f "$$ICON_DST" ] && [ -f "/usr/share/pixmaps/antigravity.png" ]; then cp "/usr/share/pixmaps/antigravity.png" "$$ICON_DST"; cp -f "/usr/share/pixmaps/antigravity.png" "$$ICON_SHARE" 2>/dev/null || true; ICON_SRC="$$ICON_DST"; fi; \
	ICON_FIELD="$$ICON_SHARE"; if [ ! -f "$$ICON_FIELD" ] && [ -f "$$ICON_DST" ]; then ICON_FIELD="$$ICON_DST"; elif [ ! -f "$$ICON_FIELD" ]; then ICON_FIELD="antigravity"; fi; \
	echo "   Creating launchers (Icon=$$ICON_FIELD)"; \
	ln -sf "$$DEST/antigravity" "$$HOME/.local/bin/antigravity2"; \
	_write_desktop() { dest="$$1"; icon="$$2"; bin="$$3"; \
		printf '%s\n' '[Desktop Entry]' 'Name=Antigravity 2' 'Comment=Antigravity 2.0 — Agentic Desktop (portable tar.gz)' 'GenericName=Text Editor' "Exec=$$bin %F" "Icon=$$icon" 'Type=Application' 'StartupNotify=false' 'StartupWMClass=Antigravity' 'Categories=TextEditor;Development;IDE;' 'MimeType=application/x-antigravity-workspace;' 'Keywords=vscode;' 'Actions=new-window;' '' '[Desktop Action new-window]' 'Name=New Window' "Exec=$$bin --new-window %F" "Icon=$$icon" > "$$dest"; \
	}; \
	_write_desktop "$$HOME/.local/share/applications/antigravity2.desktop" "$$ICON_FIELD" "$$DEST/antigravity"; chmod 644 "$$HOME/.local/share/applications/antigravity2.desktop"; \
	_write_desktop "$$DESKTOP_DIR/antigravity2.desktop" "$$ICON_FIELD" "$$DEST/antigravity"; chmod 644 "$$DESKTOP_DIR/antigravity2.desktop"; chmod +x "$$DESKTOP_DIR/antigravity2.desktop" 2>/dev/null || true; gio set "$$DESKTOP_DIR/antigravity2.desktop" metadata::trusted true 2>/dev/null || true; \
	if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$$HOME/.local/share/applications" 2>/dev/null || true; fi; \
	if command -v gtk-update-icon-cache >/dev/null 2>&1; then gtk-update-icon-cache -f -t "$$HOME/.local/share/icons" 2>/dev/null || true; fi; \
	echo "✅ Antigravity 2.0 installed to $$DEST"; \
	echo "   • Binary : $$DEST/antigravity"; \
	echo "   • CLI    : $$HOME/.local/bin/antigravity2 → $$DEST/antigravity"; \
	echo "   • App    : $$HOME/.local/share/applications/antigravity2.desktop"; \
	echo "   • Desktop: $$DESKTOP_DIR/antigravity2.desktop"; \
	echo "   • Icon   : $$ICON_FIELD"; \
	if [ -f "$$LEGACY_DEST/antigravity" ] && [ "$$LEGACY_DEST" != "$$DEST" ]; then echo "   (legacy $$LEGACY_DEST still exists — remove with: rm -rf ~/Apps/Antigravity2)"; fi; \
	if ! echo "$$PATH" | tr ':' '\n' | grep -qx "$$HOME/.local/bin"; then echo "   ⚠️  Add to PATH: export PATH=\"$$HOME/.local/bin:\$$PATH\""; fi

install-antigravity-pack: install-antigravity2 install-antigravity-ide install-cli-antigravity
	@echo ""
	@echo "✅ antigravity pack complete — binaries:"
	@printf "   • Antigravity2  %s  (CLI: %s)\n"  "$(ANTIGRAVITY2_DEST)/antigravity"  "$(HOME)/.local/bin/antigravity2"
	@printf "   • IDE           %s  (CLI: %s, %s)\n" "$(ANTIGRAVITY_IDE_DEST)/antigravity-ide" "$(HOME)/.local/bin/antigravity-ide" "$(HOME)/.local/bin/agy-ide"
	@printf "   • CLI  agy      %s  (alias %s)\n" "$(CURDIR)/bin/agy" "$(CURDIR)/bin/antigravity"

install-antigravity: install-antigravity2

uninstall-antigravity-pack: uninstall-antigravity2 uninstall-antigravity-ide
	@rm -f "$(CURDIR)/bin/agy" "$(CURDIR)/bin/antigravity"
	@echo "✅ antigravity pack uninstalled"

uninstall-antigravity2:
	@set -euo pipefail; \
	DEST="$(ANTIGRAVITY2_DEST)"; LEGACY_DEST="$$HOME/Apps/Antigravity2"; DESKTOP_DIR="$$(xdg-user-dir DESKTOP 2>/dev/null || echo "$$HOME/Desktop")"; \
	echo "Removing Antigravity 2.0 ($$DEST)"; \
	rm -rf "$$DEST" "$$LEGACY_DEST"; \
	rm -f "$$HOME/.local/bin/antigravity2" "$$HOME/.local/share/applications/antigravity2.desktop" "$$DESKTOP_DIR/antigravity2.desktop" "$$HOME/.local/share/icons/antigravity2.png"; \
	if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$$HOME/.local/share/applications" 2>/dev/null || true; fi; \
	echo "✅ Uninstalled"

# ── Antigravity IDE 2.5.5 (portable tar.gz) ──────────────────────────────────
# Upstream: https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/<ver>/linux-x64/Antigravity%20IDE.tar.gz
# Bundle: "Antigravity IDE"/antigravity-ide (ELF 191M), bin/antigravity-ide (wrapper), chrome-sandbox, locales/, resources/app/ (VS Code fork)
#         icon at resources/app/resources/linux/code.png (1024×1024). 18629 files, ~230 MB.
# Installs to ~/apps/AntigravityIDE (strip-components), exposes ~/.local/bin/antigravity-ide (+ agy-ide alias) + Desktop + applications launchers.
ANTIGRAVITY_IDE_VERSION ?= 2.5.5-4923483625488384
ANTIGRAVITY_IDE_URL ?= https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/$(ANTIGRAVITY_IDE_VERSION)/linux-x64/Antigravity%20IDE.tar.gz
ANTIGRAVITY_IDE_DEST ?= $(HOME)/apps/AntigravityIDE
ANTIGRAVITY_IDE_TMP ?= /tmp/antigravity-ide.tar.gz

install-antigravity-ide:
	@set -euo pipefail; \
	URL="$(ANTIGRAVITY_IDE_URL)"; DEST="$(ANTIGRAVITY_IDE_DEST)"; TMP="$(ANTIGRAVITY_IDE_TMP)"; \
	DESKTOP_DIR="$$(xdg-user-dir DESKTOP 2>/dev/null || echo "$$HOME/Desktop")"; \
	DISP_URL="$$(printf '%s' "$$URL" | sed 's/%20/ /g')"; \
	echo "⬇️  Antigravity IDE ($$(basename "$$DISP_URL")) → $$DEST"; \
	mkdir -p "$$DEST" "$$HOME/.local/bin" "$$HOME/.local/share/applications" "$$HOME/.local/share/icons" "$$DESKTOP_DIR"; \
	if [ -f "$$HOME/Downloads/Antigravity IDE.tar.gz" ] && echo "$$URL" | grep -q "Antigravity%20IDE.tar.gz"; then \
		echo "   Using cached ~/Downloads/Antigravity IDE.tar.gz (override with ANTIGRAVITY_IDE_URL=… or rm the file)"; \
		cp "$$HOME/Downloads/Antigravity IDE.tar.gz" "$$TMP"; \
	else \
		echo "   Downloading $$URL"; \
		curl -fsSL "$$URL" -o "$$TMP"; \
	fi; \
	echo "   Extracting → $$DEST (strip top-level 'Antigravity IDE/')"; \
	tar -xzf "$$TMP" -C "$$DEST" --strip-components=1; \
	chmod +x "$$DEST/antigravity-ide" 2>/dev/null || true; chmod +x "$$DEST/bin/antigravity-ide" 2>/dev/null || true; \
	if [ -f "$$DEST/chrome-sandbox" ]; then \
		if sudo -n true 2>/dev/null; then \
			sudo chown root:root "$$DEST/chrome-sandbox" 2>/dev/null || true; \
			sudo chmod 4755 "$$DEST/chrome-sandbox" 2>/dev/null || chmod 4755 "$$DEST/chrome-sandbox" || chmod 0755 "$$DEST/chrome-sandbox"; \
		else \
			chmod 4755 "$$DEST/chrome-sandbox" 2>/dev/null || chmod 0755 "$$DEST/chrome-sandbox"; \
		fi; \
	fi; \
	echo "   Installing icon"; \
	ICON_SRC_CAND="$$DEST/resources/app/resources/linux/code.png"; ICON_DST="$$DEST/icon.png"; ICON_SHARE="$$HOME/.local/share/icons/antigravity-ide.png"; ICON_FIELD=""; \
	if [ -f "$$ICON_SRC_CAND" ]; then cp -f "$$ICON_SRC_CAND" "$$ICON_DST"; cp -f "$$ICON_SRC_CAND" "$$ICON_SHARE" 2>/dev/null || true; ICON_FIELD="$$ICON_SHARE"; \
	elif [ -f "$$DEST/icon.png" ]; then cp -f "$$DEST/icon.png" "$$ICON_SHARE" 2>/dev/null || true; ICON_FIELD="$$ICON_SHARE"; \
	elif [ -f "/usr/share/pixmaps/antigravity.png" ]; then cp -f "/usr/share/pixmaps/antigravity.png" "$$ICON_DST"; cp -f "/usr/share/pixmaps/antigravity.png" "$$ICON_SHARE" 2>/dev/null || true; ICON_FIELD="$$ICON_SHARE"; \
	else ICON_FIELD="antigravity-ide"; fi; \
	if [ ! -f "$$ICON_FIELD" ] && [ -f "$$ICON_DST" ]; then ICON_FIELD="$$ICON_DST"; fi; \
	echo "   Creating launchers (Icon=$$ICON_FIELD)"; \
	ln -sf "$$DEST/antigravity-ide" "$$HOME/.local/bin/antigravity-ide"; \
	ln -sf "antigravity-ide" "$$HOME/.local/bin/agy-ide"; \
	chmod +x "$$HOME/.local/bin/antigravity-ide" 2>/dev/null || true; \
	_write_desktop() { dest="$$1"; icon="$$2"; bin="$$3"; \
		printf '%s\n' '[Desktop Entry]' 'Name=Antigravity IDE' 'Comment=Antigravity IDE 2.5.5 — VS Code fork (portable tar.gz)' 'GenericName=Text Editor' "Exec=$$bin %F" "Icon=$$icon" 'Type=Application' 'StartupNotify=false' 'StartupWMClass=Antigravity IDE' 'Categories=TextEditor;Development;IDE;' 'MimeType=application/x-antigravity-workspace;' 'Keywords=vscode;antigravity;' 'Actions=new-window;' '' '[Desktop Action new-window]' 'Name=New Window' "Exec=$$bin --new-window %F" "Icon=$$icon" > "$$dest"; \
	}; \
	_write_desktop "$$HOME/.local/share/applications/antigravity-ide.desktop" "$$ICON_FIELD" "$$DEST/antigravity-ide"; chmod 644 "$$HOME/.local/share/applications/antigravity-ide.desktop"; \
	_write_desktop "$$DESKTOP_DIR/antigravity-ide.desktop" "$$ICON_FIELD" "$$DEST/antigravity-ide"; chmod 644 "$$DESKTOP_DIR/antigravity-ide.desktop"; chmod +x "$$DESKTOP_DIR/antigravity-ide.desktop" 2>/dev/null || true; gio set "$$DESKTOP_DIR/antigravity-ide.desktop" metadata::trusted true 2>/dev/null || true; \
	if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$$HOME/.local/share/applications" 2>/dev/null || true; fi; \
	if command -v gtk-update-icon-cache >/dev/null 2>&1; then gtk-update-icon-cache -f -t "$$HOME/.local/share/icons" 2>/dev/null || true; fi; \
	echo "✅ Antigravity IDE installed to $$DEST"; \
	echo "   • Binary : $$DEST/antigravity-ide  (+ $$DEST/bin/antigravity-ide wrapper)"; \
	echo "   • CLI    : $$HOME/.local/bin/antigravity-ide → $$DEST/antigravity-ide  (alias agy-ide)"; \
	echo "   • App    : $$HOME/.local/share/applications/antigravity-ide.desktop"; \
	echo "   • Desktop: $$DESKTOP_DIR/antigravity-ide.desktop"; \
	echo "   • Icon   : $$ICON_FIELD  (source: $$ICON_SRC_CAND)"; \
	if ! echo "$$PATH" | tr ':' '\n' | grep -qx "$$HOME/.local/bin"; then echo "   ⚠️  Add to PATH: export PATH=\"$$HOME/.local/bin:\$$PATH\""; fi

uninstall-antigravity-ide:
	@set -euo pipefail; \
	DEST="$(ANTIGRAVITY_IDE_DEST)"; DESKTOP_DIR="$$(xdg-user-dir DESKTOP 2>/dev/null || echo "$$HOME/Desktop")"; \
	echo "Removing Antigravity IDE ($$DEST)"; \
	rm -rf "$$DEST"; \
	rm -f "$$HOME/.local/bin/antigravity-ide" "$$HOME/.local/bin/agy-ide" "$$HOME/.local/share/applications/antigravity-ide.desktop" "$$DESKTOP_DIR/antigravity-ide.desktop" "$$HOME/.local/share/icons/antigravity-ide.png"; \
	if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$$HOME/.local/share/applications" 2>/dev/null || true; fi; \
	echo "✅ Uninstalled"

install-ai-goose-cli:
	@set -e; \
        LATEST_TAG="$$(curl -fsSL https://api.github.com/repos/block/goose/releases/latest \
                | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"; \
        echo "Latest goose release: $$LATEST_TAG"; \
        echo "Downloading installer..."; \
        curl -fsSL \
                "https://github.com/block/goose/releases/download/$$LATEST_TAG/download_cli.sh" \
                -o /tmp/download_goose_cli.sh; \
        chmod +x /tmp/download_goose_cli.sh; \
        echo "Installing goose to $$HOME/dotfiles/bin"; \
        GOOSE_BIN_DIR="$$HOME/ai-files/bin" \
                bash /tmp/download_goose_cli.sh

install-aider-desk:
	@set -e; \
	echo "Detecting latest aider-desk release..."; \
	RELEASE_JSON="$$(curl -fsSL https://api.github.com/repos/hotovo/aider-desk/releases/latest)"; \
	TAG="$$(echo "$$RELEASE_JSON" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"; \
	APPIMAGE_URL="$$(echo "$$RELEASE_JSON" \
		| sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*x86_64\.AppImage\)".*/\1/p')"; \
	if [ -z "$$APPIMAGE_URL" ]; then \
		echo "ERROR: x86_64 AppImage not found for $$TAG"; \
		exit 1; \
	fi; \
	mkdir -p "$$HOME/Applications"; \
	DEST="$$HOME/Applications/$$(basename $$APPIMAGE_URL)"; \
	echo "Latest version: $$TAG"; \
	echo "Downloading to $$DEST"; \
	curl -fsSL "$$APPIMAGE_URL" -o "$$DEST"; \
	chmod +x "$$DEST"; \
	echo "aider-desk installed successfully"

install-desktop-ai-goose:
	@set -e; \
        echo "Detecting latest goose desktop release..."; \
        RELEASE_JSON="$$(curl -fsSL https://api.github.com/repos/block/goose/releases/latest)"; \
        TAG="$$(echo "$$RELEASE_JSON" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"; \
        DEB_URL="$$(echo "$$RELEASE_JSON" \
                | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*goose_[^"]*_amd64\.deb\)".*/\1/p')"; \
        if [ -z "$$DEB_URL" ]; then \
                echo "ERROR: amd64 .deb not found for $$TAG"; \
                exit 1; \
        fi; \
        DEB_FILE="/tmp/$$(basename $$DEB_URL)"; \
        echo "Latest version: $$TAG"; \
        echo "Downloading $$DEB_FILE"; \
        curl -fsSL "$$DEB_URL" -o "$$DEB_FILE"; \
        echo "Installing goose desktop (requires sudo)..."; \
        sudo dpkg -i "$$DEB_FILE"; \
        echo "goose desktop installed successfully"

install-opencode-desktop:
	@set -e; \
	APPIMAGE_URL="https://opencode.ai/download/linux-x64-appimage"; \
	mkdir -p "$$HOME/Applications"; \
	DEST="$$HOME/Applications/opencode-desktop.AppImage"; \
	echo "Downloading to $$DEST"; \
	curl -fsSL "$$APPIMAGE_URL" -o "$$DEST"; \
	chmod +x "$$DEST";\
	echo "opencode-desktop installed successfully"

install-cli-opencode:
	@set -euo pipefail; \
	mkdir -p "$(CURDIR)/bin"; \
	os="$$(uname -s | tr '[:upper:]' '[:lower:]')"; \
	case "$$os" in \
		darwin*) archive="opencode-darwin-x64.zip" ;; \
		linux*)  archive="opencode-linux-x64.tar.gz" ;; \
		*) echo "unsupported os: $$os"; exit 1 ;; \
	esac; \
	url="https://github.com/anomalyco/opencode/releases/latest/download/$$archive"; \
	tmp="$$(mktemp -d)"; \
	echo "Downloading $$url"; \
	curl -fsSL "$$url" -o "$$tmp/$$archive"; \
	case "$$archive" in \
		*.tar.gz) tar -xzf "$$tmp/$$archive" -C "$$tmp" ;; \
		*.zip) unzip -q "$$tmp/$$archive" -d "$$tmp" ;; \
	esac; \
	mv "$$tmp/opencode" "$(CURDIR)/bin/opencode"; \
	chmod +x "$(CURDIR)/bin/opencode"; \
	rm -rf "$$tmp"; \
	echo "Installed to $(CURDIR)/bin/opencode"

# ── Antigravity CLI (agy) — single binary → ~/ai-files/bin/ ─────────────────
# Upstream installer: https://antigravity.google/cli/install.sh  (shells out to agy install)
# Manifest: https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/<platform>.json
# Payload: cli_linux_x64.tar.gz (one file: "antigravity" 199M ELF) → installed as "agy", sha512-verified
# Supports ANTIGRAVITY_CLI_VERSION=1.1.20 pin or latest (default resolves via manifest)
ANTIGRAVITY_CLI_VERSION ?=
ANTIGRAVITY_CLI_MANIFEST_BASE ?= https://antigravity-cli-auto-updater-974169037036.us-central1.run.app
install-cli-antigravity:
	@set -euo pipefail; \
	BIN_DIR="$(CURDIR)/bin"; mkdir -p "$$BIN_DIR"; \
	case "$$(uname -s)" in Darwin) os=darwin;; Linux) os=linux;; *) echo "Unsupported OS: $$(uname -s)" >&2; exit 1;; esac; \
	case "$$(uname -m)" in x86_64|amd64) arch=amd64;; arm64|aarch64) arch=arm64;; *) echo "Unsupported arch: $$(uname -m)" >&2; exit 1;; esac; \
	if [ "$$os" = linux ] && { [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || ldd /bin/ls 2>&1 | grep -q musl; }; then plat="linux_$${arch}_musl"; \
	elif [ "$$os" = linux ]; then plat="linux_$${arch}"; else plat="$${os}_$${arch}"; fi; \
	if [ -n "$(ANTIGRAVITY_CLI_VERSION)" ]; then \
		ver="$(ANTIGRAVITY_CLI_VERSION)"; ver="$${ver#v}"; \
		case "$$ver" in *[!0-9A-Za-z.-]*) echo "invalid ANTIGRAVITY_CLI_VERSION: $$ver" >&2; exit 1;; esac; \
		case "$$plat" in linux_amd64) url="https://storage.googleapis.com/antigravity-public/antigravity-cli/$$ver-5830032204103680/linux-x64/cli_linux_x64.tar.gz";; \
			linux_arm64) url="https://storage.googleapis.com/antigravity-public/antigravity-cli/$$ver-5830032204103680/linux-arm64/cli_linux_arm64.tar.gz";; \
			darwin_amd64) url="https://storage.googleapis.com/antigravity-public/antigravity-cli/$$ver-5830032204103680/darwin-x64/cli_mac_x64.tar.gz";; \
			darwin_arm64) url="https://storage.googleapis.com/antigravity-public/antigravity-cli/$$ver-5830032204103680/darwin-arm/cli_mac_arm64.tar.gz";; \
			*) echo "pinned version: unsupported platform $$plat" >&2; exit 1;; esac; \
		echo "Antigravity CLI $$ver (pinned, platform $$plat)"; \
		sha512=""; \
	else \
		manifest_url="$(ANTIGRAVITY_CLI_MANIFEST_BASE)/manifests/$$plat.json"; \
		echo "Resolving Antigravity CLI (platform $$plat) via $$manifest_url"; \
		manifest="$$(curl -fsSL "$$manifest_url")"; test -n "$$manifest" || { echo "could not fetch manifest" >&2; exit 1; }; \
		ver="$$(printf '%s' "$$manifest" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"; \
		url="$$(printf '%s' "$$manifest" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"; \
		sha512="$$(printf '%s' "$$manifest" | sed -n 's/.*"sha512"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"; \
		test -n "$$url" || { echo "manifest missing url" >&2; exit 1; }; \
		echo "Latest: $$ver  sha512 $${sha512:0:16}…"; \
	fi; \
	tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT INT TERM; \
	archive="$$tmp/cli.tar.gz"; echo "Downloading $$url"; curl -fsSL "$$url" -o "$$archive"; \
	if [ -n "$$sha512" ]; then \
		echo "$$sha512  $$archive" | sha512sum -c -; \
	else echo "⚠️  No sha512 for pinned build — skipping verification"; fi; \
	tar -xzf "$$archive" -C "$$tmp" antigravity; test -f "$$tmp/antigravity" || { echo "tar missing antigravity" >&2; exit 1; }; \
	install -m 0755 "$$tmp/antigravity" "$$BIN_DIR/agy"; \
	ln -sf agy "$$BIN_DIR/antigravity"; \
	echo "✅ agy $$ver ($$plat) → $$BIN_DIR/agy  (alias antigravity)"; \
	"$$BIN_DIR/agy" --version 2>&1 | head -n 5 || true; \
	if ! echo "$$PATH" | tr ':' '\n' | grep -qx "$$BIN_DIR"; then echo "Add to PATH: export PATH=\"$$BIN_DIR:\$$PATH\""; fi

install-cli-commandcode:
	npm install -g command-code

install-grok-amd64:
	@set -e; \
	VERSION="$${VERSION:-$$(curl -fsSL https://x.ai/cli/stable)}"; \
	PLATFORM="linux-x86_64"; \
	BIN_DIR="$$HOME/ai-files/bin"; \
	mkdir -p "$$BIN_DIR"; \
	URL="https://x.ai/cli/grok-$$VERSION-$$PLATFORM"; \
	echo "Installing Grok $$VERSION ($$PLATFORM)..."; \
	curl -fsSL "$$URL" -o "$$BIN_DIR/grok"; \
	chmod +x "$$BIN_DIR/grok"; \
	ln -sf grok "$$BIN_DIR/agent"; \
	echo "Installed to $$BIN_DIR/grok"; \
	if ! echo "$$PATH" | tr ':' '\n' | grep -qx "$$BIN_DIR"; then \
		echo ''; \
		echo 'Add to PATH:'; \
		echo '  export PATH="$$HOME/dotfiles/bin:$$PATH"'; \
	fi

install-rtk:
	@set -euo pipefail; \
	TAG="$$(curl -fsSL https://api.github.com/repos/rtk-ai/rtk/releases/latest \
		| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"; \
	echo "Latest rtk release: $$TAG"; \
	BIN_DIR="$$HOME/ai-files/bin"; \
	mkdir -p "$$BIN_DIR"; \
	case "$$(uname -s)" in \
		Darwin) OS=apple-darwin ;; \
		Linux)  OS=unknown-linux-musl ;; \
		*) echo "ERROR: unsupported os: $$(uname -s)"; exit 1 ;; \
	esac; \
	case "$$(uname -m)" in \
		x86_64|amd64) ARCH=x86_64 ;; \
		arm64|aarch64) ARCH=aarch64; [ "$$OS" != "apple-darwin" ] && OS=unknown-linux-gnu ;; \
		*) echo "ERROR: unsupported arch: $$(uname -m)"; exit 1 ;; \
	esac; \
	TARGET="$$ARCH-$$OS"; \
	ARCHIVE="rtk-$$TARGET.tar.gz"; \
	URL="https://github.com/rtk-ai/rtk/releases/download/$$TAG/$$ARCHIVE"; \
	echo "Downloading $$ARCHIVE ($$TARGET)..."; \
	tmp="$$(mktemp -d)"; \
	curl -fsSL "$$URL" -o "$$tmp/$$ARCHIVE"; \
	tar -xzf "$$tmp/$$ARCHIVE" -C "$$tmp"; \
	RTK_BIN="$$(find "$$tmp" -type f -name rtk -print -quit)"; \
	if [ -z "$$RTK_BIN" ]; then echo "ERROR: rtk binary not found in $$ARCHIVE"; exit 1; fi; \
	mv "$$RTK_BIN" "$$BIN_DIR/rtk"; \
	chmod +x "$$BIN_DIR/rtk"; \
	rm -rf "$$tmp"; \
	echo "✅ Installed rtk $$TAG ($$TARGET) to $$BIN_DIR/rtk"; \
	if ! echo "$$PATH" | tr ':' '\n' | grep -qx "$$BIN_DIR"; then \
		echo ''; \
		echo 'Add to PATH:'; \
		echo "  export PATH=\"$$BIN_DIR:\$$PATH\""; \
	fi

## rtk enablement — install rtk first (`make install-rtk`), then enable per agent.
## rtk is a CLI proxy, NOT an MCP server; `rtk init` writes each agent's
## hook/plugin/rules files itself.
## Per-agent scope (rtk-enforced):
##   Claude   - global hook (rtk-enable-claude) OR local CLAUDE.md instructions
##   OpenCode - global plugin ONLY (no local mode)
##   Kilo     - project-scoped rules ONLY (no global mode)
##   zcode    - NOT supported by rtk

_rtk-require:
	@command -v rtk >/dev/null 2>&1 || { \
		echo "ERROR: rtk not found on PATH."; \
		echo "Install with: make install-rtk"; \
		echo "Or: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"; \
		exit 1; \
	}

# --- per-agent enable (best/default mode) ---
# Claude Code: native PreToolUse hook (global). --auto-patch = non-interactive settings.json patch.
rtk-enable-claude: _rtk-require
	RTK_TELEMETRY_DISABLED=1 rtk init -g --auto-patch < /dev/null

# OpenCode: TS plugin (global-only in rtk).
rtk-enable-opencode: _rtk-require
	RTK_TELEMETRY_DISABLED=1 rtk init -g --opencode < /dev/null

# Kilo Code: project-scoped rules file at .kilocode/rules/rtk-rules.md (its only mode).
rtk-enable-kilocode: _rtk-require
	RTK_TELEMETRY_DISABLED=1 rtk init --agent kilocode < /dev/null

# rtk has no zcode integration (not in `rtk init --agent`). Informational no-op.
rtk-enable-zcode:
	@echo "rtk does not support zcode (not in its 'rtk init --agent' list). Skipping."

# --- aggregates ---
# Global/automatic mode for all supported agents (Claude hook + OpenCode plugin + Kilo rules).
rtk-enable: rtk-enable-claude rtk-enable-opencode rtk-enable-kilocode
	@echo "✅ rtk enabled (global/auto): Claude hook, OpenCode plugin, Kilo Code rules."
	@echo "   Restart your agents to activate."

# Local/project mode for agents that support it (Claude CLAUDE.md instructions + Kilo rules).
# OpenCode has no local mode; zcode is unsupported.
rtk-enable-local: _rtk-require
	RTK_TELEMETRY_DISABLED=1 rtk init < /dev/null
	RTK_TELEMETRY_DISABLED=1 rtk init --agent kilocode < /dev/null
	@echo "✅ rtk enabled (local): Claude CLAUDE.md instructions + .rtk/filters.toml + Kilo Code rules."
	@echo "   OpenCode has no local mode; zcode is unsupported."

# Global disable: removes the global Claude hook + RTK.md + settings.json entry.
rtk-disable: _rtk-require
	RTK_TELEMETRY_DISABLED=1 rtk init -g --uninstall < /dev/null
	@echo "✅ rtk disabled (global)."

# Local disable: rtk refuses local uninstall ("manually remove RTK from CLAUDE.md"),
# so remove project artifacts by hand. Strips the <!-- rtk-instructions --> block.
rtk-disable-local:
	@if [ -f CLAUDE.md ]; then \
		sed -i '/<!-- rtk-instructions /,/<!-- \/rtk-instructions -->/d' CLAUDE.md; \
	fi
	@rm -rf .rtk
	@rm -f .kilocode/rules/rtk-rules.md
	@echo "✅ rtk disabled (local): stripped CLAUDE.md block, removed .rtk/ and .kilocode/rules/rtk-rules.md."

## graphify enablement — install graphify first (`make install-graphify`), then enable per agent.
## graphify registers the /graphify skill into each platform's config dir via
## `graphify install --platform <p>` (PyPI package `graphifyy`, CLI command `graphify`).
## Per-agent scope:
##   Claude   - global skill via `graphify install --platform claude`
##   OpenCode - global skill via `graphify install --platform opencode`
##   Kilo     - global skill via `graphify install --platform kilo`   (rtk names this "kilocode")
##   zcode    - NOT supported by graphify (not in its --platform list)

_graphify-require:
	@command -v graphify >/dev/null 2>&1 || { \
		echo "ERROR: graphify not found on PATH."; \
		echo "Install with: make install-graphify"; \
		echo "Or: uv tool install graphifyy   (or: pipx install graphifyy)"; \
		exit 1; \
	}

# --- per-agent enable (global/user mode; copies the /graphify skill) ---
# Claude Code: skill copied to ~/.claude/skills/graphify.
graphify-enable-claude: _graphify-require
	graphify install --platform claude < /dev/null

# OpenCode: skill copied to the opencode config dir.
graphify-enable-opencode: _graphify-require
	graphify install --platform opencode < /dev/null

# Kilo Code: skill copied to the kilo config dir (graphify platform name is "kilo").
graphify-enable-kilocode: _graphify-require
	graphify install --platform kilo < /dev/null

# graphify has no zcode integration (zcode not in its --platform list). Informational no-op.
graphify-enable-zcode:
	@echo "graphify does not support zcode (not in its --platform list). Skipping."

# --- aggregates ---
# Global/user mode: install the /graphify skill for every supported agent.
graphify-enable: graphify-enable-claude graphify-enable-opencode graphify-enable-kilocode
	@echo "✅ graphify enabled (global): Claude, OpenCode, Kilo Code skills installed."
	@echo "   Restart your agents, then run /graphify . in a project."

# Project-local mode: install the skill into THIS repo (--project), so it can be committed/shared.
graphify-enable-local: _graphify-require
	graphify install --platform claude --project < /dev/null
	graphify install --platform opencode --project < /dev/null
	graphify install --platform kilo --project < /dev/null
	@echo "✅ graphify enabled (project-local): skills written under the current repo."

# --- disable ---
# graphify uninstall removes the skill from ALL detected platforms (global + project) at once.
graphify-disable: _graphify-require
	graphify uninstall < /dev/null
	@echo "✅ graphify disabled (uninstalled from all detected platforms)."

# Same, and also delete the built graphify-out/ graph artifacts.
graphify-disable-purge: _graphify-require
	graphify uninstall --purge < /dev/null
	@echo "✅ graphify disabled + graphify-out/ purged."

install-cli-reasonix:
	@set -euo pipefail; \
	TAG="$$(curl -fsSL https://api.github.com/repos/esengine/DeepSeek-Reasonix/releases/latest \
		| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"; \
	echo "Latest DeepSeek-Reasonix release: $$TAG"; \
	BIN_DIR="$(CURDIR)/bin"; \
	mkdir -p "$$BIN_DIR"; \
	ARCHIVE="reasonix-linux-amd64.tar.gz"; \
	URL="https://github.com/esengine/DeepSeek-Reasonix/releases/download/$$TAG/$$ARCHIVE"; \
	echo "Downloading $$ARCHIVE from $$TAG..."; \
	tmp="$$(mktemp -d)"; \
	curl -fsSL "$$URL" -o "$$tmp/$$ARCHIVE"; \
	tar -xzf "$$tmp/$$ARCHIVE" -C "$$tmp"; \
	REASONIX_BIN="$$(find "$$tmp" -type f -name reasonix -print -quit)"; \
	if [ -z "$$REASONIX_BIN" ]; then echo "ERROR: reasonix binary not found in $$ARCHIVE"; exit 1; fi; \
	mv "$$REASONIX_BIN" "$$BIN_DIR/reasonix"; \
	chmod +x "$$BIN_DIR/reasonix"; \
	rm -rf "$$tmp"; \
	echo "✅ Installed reasonix $$TAG to $$BIN_DIR/reasonix"

# Ensure ~/.reasonix/config.toml is a symlink to ~/keyfiles/dotreasonix/config.toml.
# If the config is absent, or is not a link pointing to the keyfiles copy, the
# existing file is backed up to config.toml.bak and the link is (re)created.
config-reasonix:
	@set -euo pipefail; \
	RZ_HOME="$(HOME)/.reasonix"; \
	CONFIG="$$RZ_HOME/config.toml"; \
	SOURCE="$(HOME)/keyfiles/dotreasonix/config.toml"; \
	if [ -L "$$CONFIG" ] && [ "$$(readlink -f "$$CONFIG")" = "$$(readlink -f "$$SOURCE")" ]; then \
		echo "✅ reasonix config already links to $$SOURCE"; \
	elif [ -e "$$CONFIG" ] || [ -L "$$CONFIG" ]; then \
		mv "$$CONFIG" "$$CONFIG.bak"; \
		echo "Backed up previous config to $$CONFIG.bak"; \
		ln -s "$$SOURCE" "$$CONFIG"; \
		echo "✅ Created symlink: $$CONFIG -> $$SOURCE"; \
	else \
		mkdir -p "$$RZ_HOME"; \
		ln -s "$$SOURCE" "$$CONFIG"; \
		echo "✅ Created symlink: $$CONFIG -> $$SOURCE"; \
	fi

# OpenCode config files managed as symlinks: ~/.config/opencode/<name> -> ~/keyfiles/dotopencode/<name>.
# Extend this list to manage additional files; the config-opencode target loops over it.
OPENCODE_CONFIG_FILES ?= opencode.jsonc tui.json oh-my-opencode-slim.json

# Ensure each file in ~/.config/opencode/ is a symlink to ~/keyfiles/dotopencode/<name>.
# - If the keyfiles source exists: an existing target (file or wrong link) is backed
#   up to <name>.bak, then linked (reasonix behavior).
# - If the keyfiles source is absent but a real file exists at the target: that file
#   is MIGRATED into ~/keyfiles/dotopencode/<name> and linked back (first-run friendly).
config-opencode:
	@set -euo pipefail; \
	OC_HOME="$(HOME)/.config/opencode"; \
	SRC_DIR="$(HOME)/keyfiles/dotopencode"; \
	mkdir -p "$$OC_HOME" "$$SRC_DIR"; \
	link_one() { \
		name="$$1"; \
		CONFIG="$$OC_HOME/$$name"; \
		SOURCE="$$SRC_DIR/$$name"; \
		if [ -L "$$CONFIG" ] && [ "$$(readlink -f "$$CONFIG")" = "$$(readlink -f "$$SOURCE")" ]; then \
			echo "✅ opencode $$name already links to $$SOURCE"; \
		elif [ ! -e "$$SOURCE" ] && [ -f "$$CONFIG" ] && [ ! -L "$$CONFIG" ]; then \
			mv "$$CONFIG" "$$SOURCE"; \
			ln -s "$$SOURCE" "$$CONFIG"; \
			echo "✅ Migrated $$name into $$SOURCE and linked $$CONFIG -> $$SOURCE"; \
		else \
			if [ -e "$$CONFIG" ] || [ -L "$$CONFIG" ]; then \
				mv "$$CONFIG" "$$CONFIG.bak"; \
				echo "Backed up previous $$name to $$CONFIG.bak"; \
			fi; \
			ln -s "$$SOURCE" "$$CONFIG"; \
			echo "✅ Created symlink: $$CONFIG -> $$SOURCE"; \
		fi; \
	}; \
	for name in $(OPENCODE_CONFIG_FILES); do link_one "$$name"; done

install-gemini-cli:
	npm install -g @google/gemini-cli

install-mcp-memory-service:
	pipx mcp-memory-service
	pipx inject mcp-memory-service onnxruntime

install-mcp-ssh-manager:
	npm install -g mcp-ssh-manager

install-cli-to-local-bin:
	@set -e; \
	SRC="$(PWD)/bin/ai-files"; \
	DST="$(HOME)/.local/bin/ai-files"; \
	if [ ! -f "$$SRC" ]; then \
		echo "Error: Source file not found: $$SRC"; \
		exit 1; \
	fi; \
	mkdir -p "$(HOME)/.local/bin"; \
	if [ -L "$$DST" ]; then \
		echo "Removing existing symlink: $$DST"; \
		rm "$$DST"; \
	elif [ -e "$$DST" ]; then \
		echo "Error: $$DST exists and is not a symlink"; \
		exit 1; \
	fi; \
	ln -s "$$SRC" "$$DST"; \
	echo "✅ Created symlink: $$DST -> $$SRC"

## Release management

release:
	@echo "🔄 Building release..."
	make magic
	@echo ""
	@echo "📦 Creating release archive..."
	@RELEASE_DATE=$$(date +%Y.%m.%d); \
	RELEASE_NAME="ai-files-$$RELEASE_DATE"; \
	RELEASE_TAG="$$RELEASE_DATE"; \
	RELEASE_ZIP="$$RELEASE_NAME.zip"; \
	echo "Release: $$RELEASE_NAME"; \
	echo "Tag: $$RELEASE_TAG"; \
	cd dist && zip -qr "../$$RELEASE_ZIP" . && cd ..; \
	echo "✅ Created archive: $$RELEASE_ZIP"; \
	echo ""; \
	echo "🏷️  Creating git tag $$RELEASE_TAG..."; \
	if git rev-parse "$$RELEASE_TAG" >/dev/null 2>&1; then \
		echo "Warning: Tag $$RELEASE_TAG already exists, skipping tag creation"; \
	else \
		git tag -a "$$RELEASE_TAG" -m "Release $$RELEASE_NAME"; \
		git push origin "$$RELEASE_TAG"; \
		echo "✅ Tag created and pushed: $$RELEASE_TAG"; \
	fi; \
	echo ""; \
	echo "📤 Creating GitHub release..."; \
	if gh release view "$$RELEASE_TAG" >/dev/null 2>&1; then \
		echo "Release already exists, uploading asset..."; \
		gh release upload "$$RELEASE_TAG" "$$RELEASE_ZIP" --clobber; \
	else \
		gh release create "$$RELEASE_TAG" \
			--title "$$RELEASE_NAME" \
			--generate-notes \
			"$$RELEASE_ZIP"; \
	fi; \
	echo "✅ Release created: $$RELEASE_TAG"; \
	echo ""; \
	echo "🎉 Release complete!"; \
	echo "   Archive: $$RELEASE_ZIP"; \
	echo "   Tag: $$RELEASE_TAG"; \
	echo "   URL: $$(gh release view $$RELEASE_TAG --json url -q .url)"

install-cli-prime-agent:
	@set -eu; \
	PRIME_AGENT_DOWNLOAD_BASE_URL="$${PRIME_AGENT_DOWNLOAD_BASE_URL:-https://pub-728493de92a943e2a9b2d17b4719f318.r2.dev}"; \
	PRIME_AGENT_RELEASE_CHANNEL="$${PRIME_AGENT_RELEASE_CHANNEL:-stable}"; \
	PRIME_AGENT_PACKAGE="$${PRIME_AGENT_PACKAGE:-prime-agent}"; \
	PRIME_AGENT_CMD="$${PRIME_AGENT_CMD:-prime-agent}"; \
	command -v curl >/dev/null 2>&1 || { echo "error: curl is required"; exit 1; }; \
	command -v sha256sum >/dev/null 2>&1 || { echo "error: sha256sum is required"; exit 1; }; \
	command -v npm >/dev/null 2>&1 || { echo "error: npm is required"; exit 1; }; \
	command -v node >/dev/null 2>&1 || { echo "error: Node.js >= 20.6.0 is required"; exit 1; }; \
	node -e 'const [a,b,c]=process.versions.node.split(".").map(Number); process.exit(a > 20 || (a === 20 && (b > 6 || (b === 6 && c >= 0))) ? 0 : 1)' \
		|| { echo "error: Node.js >= 20.6.0 is required; found $$(node --version)"; exit 1; }; \
	tmp_dir="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp_dir"' EXIT INT TERM; \
	base_url="$${PRIME_AGENT_DOWNLOAD_BASE_URL%/}"; \
	channel="$${PRIME_AGENT_RELEASE_CHANNEL}"; \
	echo "Resolving Prime Agent $$channel release..."; \
	version="$$(curl -fsSL "$$base_url/$$channel" | tr -d '[:space:]')"; \
	version="$${version#v}"; \
	test -n "$$version" || { echo "error: could not resolve Prime Agent version"; exit 1; }; \
	case "$$version" in \
		*[!0-9A-Za-z.-]*) echo "error: invalid Prime Agent version: $$version"; exit 1 ;; \
	esac; \
	tarball="$$(printf '%s-%s.tgz' "$${PRIME_AGENT_PACKAGE}" "$$version")"; \
	release_url="$$base_url/releases/v$$version"; \
	echo "Downloading Prime Agent v$$version..."; \
	curl -fsSL "$$release_url/SHA256SUMS" -o "$$tmp_dir/SHA256SUMS"; \
	curl -fsSL "$$release_url/$$tarball" -o "$$tmp_dir/$$tarball"; \
	awk -v file="$$tarball" '$$2 == file { print; found=1; exit } END { if (!found) exit 1 }' \
		"$$tmp_dir/SHA256SUMS" > "$$tmp_dir/SHA256SUMS.selected" \
		|| { echo "error: checksum for $$tarball not found"; exit 1; }; \
	(cd "$$tmp_dir" && sha256sum -c SHA256SUMS.selected); \
	echo "Installing Prime Agent v$$version..."; \
	PRIME_AGENT_BOOTSTRAP_TOOLS_ON_INSTALL=1 \
	PRIME_AGENT_BOOTSTRAP_KERNEL_ON_INSTALL=1 \
	PRIME_AGENT_INSTALL_UV=0 \
	npm install -g --no-fund --no-audit --loglevel=error --progress=false "$$tmp_dir/$$tarball"; \
	echo "Prime Agent installed: $$(command -v "$${PRIME_AGENT_CMD}" || true)"

install-cli-pi-agent:
	@set -eu; \
	MAKEFILE_DIR="$$(cd "$$(dirname "$$(realpath "$(lastword $(MAKEFILE_LIST))")")" && pwd)"; \
	INSTALL_DIR="$$MAKEFILE_DIR/bin"; \
	if command -v pi >/dev/null 2>&1; then \
		echo "pi already installed: $$(command -v pi)"; \
		pi --version || true; \
		exit 0; \
	fi; \
	OS="$$(uname -s | tr '[:upper:]' '[:lower:]')"; \
	ARCH="$$(uname -m)"; \
	case "$$OS/$$ARCH" in \
		darwin/arm64)  ASSET="pi-darwin-arm64.tar.gz" ;; \
		darwin/x86_64) ASSET="pi-darwin-x64.tar.gz" ;; \
		linux/x86_64)  ASSET="pi-linux-x64.tar.gz" ;; \
		linux/aarch64) ASSET="pi-linux-arm64.tar.gz" ;; \
		*) ASSET="" ;; \
	esac; \
	if [ -n "$$ASSET" ] && command -v curl >/dev/null 2>&1; then \
		echo "Installing Pi binary ($$ASSET)..."; \
		TMP="$$(mktemp -d)"; \
		trap 'rm -rf "$$TMP"' EXIT; \
		if curl -fsSL \
			"https://github.com/badlogic/pi-mono/releases/latest/download/$$ASSET" \
			-o "$$TMP/pi.tar.gz"; then \
			mkdir -p "$$INSTALL_DIR"; \
			tar -xzf "$$TMP/pi.tar.gz" -C "$$TMP"; \
			if [ -d "$$TMP/pi" ]; then \
				PI_SRC="$$TMP/pi"; \
			else \
				PI_SRC="$$TMP"; \
			fi; \
			install -m 0755 "$$PI_SRC/pi" "$$INSTALL_DIR/pi"; \
			for wasm in "$$PI_SRC"/*.wasm; do \
				if [ -f "$$wasm" ]; then \
					cp -a "$$wasm" "$$INSTALL_DIR/"; \
				fi; \
			done; \
			echo "Installed: $$INSTALL_DIR/pi"; \
			exit 0; \
		fi; \
		echo "Binary unavailable, falling back to official installer..."; \
	fi;

### Orchestration


install-opencode-ohmy-slim:
	bunx oh-my-opencode-slim@latest install

