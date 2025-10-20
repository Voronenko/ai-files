### 
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

update-externals:
	rm -rf plugins/spec-kit
	gilt overlay

build:
	# Remove old build
	rm -rf ./dist/
	mkdir -p ./dist/.ai-files
	cp -r plugins ./dist/.ai-files/
	@echo "Copying and linking plugin files..."

	# Ensure target directories exist one level up from .ai-files
	mkdir -p dist/.roo/commands
	mkdir -p dist/.kilocode/workflows
	mkdir -p dist/.claude/commands

	# 1) Link dotspecify → .specify (relative to dist/)
	cd dist && ln -sfn .ai-files/plugins/spec-kit/dotspecify .specify

	# 2) Copy plugin files to .roo/.kilocode and symlink to .claude
	@find dist/.ai-files/plugins/spec-kit/specflows -type f | \
	while IFS= read -r file; do \
		base_name=`basename "$$file"`; \
		cp -f "$$file" "dist/.roo/commands/$$base_name"; \
		cp -f "$$file" "dist/.kilocode/workflows/$$base_name"; \
		rel_from_claude=`realpath --relative-to=dist/.claude/commands "$$file"`; \
		ln -sfn "$$rel_from_claude" "dist/.claude/commands/$$base_name"; \
	done


build-ideal:
	# Remove old build
	rm -rf ./dist/
	mkdir -p ./dist/.ai-files
	cp -r plugins ./dist/.ai-files/
	@echo "Creating relative symlinks for plugins..."

	# Ensure target directories exist one level up from .ai-files
	mkdir -p dist/.roo/commands
	mkdir -p dist/.kilocode/workflows
	mkdir -p dist/.claude/commands

	# 1) Link dotspecify → .specify (relative to dist/)
	cd dist && ln -sfn .ai-files/plugins/spec-kit/dotspecify .specify

	# 2) Link plugin files to .roo/.kilocode/.claude with proper relative paths
	@find dist/.ai-files/plugins/spec-kit/specflows -type f | \
	while IFS= read -r file; do \
		base_name=`basename "$$file"`; \
		rel_from_roo=`realpath --relative-to=dist/.roo/commands "$$file"`; \
		rel_from_kilo=`realpath --relative-to=dist/.kilocode/workflows "$$file"`; \
		rel_from_claude=`realpath --relative-to=dist/.claude/commands "$$file"`; \
		ln -sfn "$$rel_from_roo" "dist/.roo/commands/$$base_name"; \
		ln -sfn "$$rel_from_kilo" "dist/.kilocode/workflows/$$base_name"; \
		ln -sfn "$$rel_from_claude" "dist/.claude/commands/$$base_name"; \
	done

	@echo "✅ Relative symlinks created under dist/"

link-roo:
	@if [ ! -L ~/.roo ]; then \
		ln -s ~/ai-files/dist/roo ~/.roo; \
	fi
adr-toc: adr-graph
	adr generate toc > ./docs/architecture/decisions/README.md
	@echo "## Architecture Decision Graph\n\n![Architecture Decision Graph](graph.svg)\n" >> ./docs/architecture/decisions/README.md
adr-graph:
	adr generate graph > ./docs/architecture/decisions/graph.dot
	dot -Tsvg ./docs/architecture/decisions/graph.dot -o ./docs/architecture/decisions/graph.svg

install-mermaid-cli:
	npm install -g @mermaid-js/mermaid-cli

install-cli-anthropic-claude-code:
	npm install -g @anthropic-ai/claude-code
	echo "Use cli command claude"
	echo "Refer: obsidian://open?vault=KB&file=pages%2FDEVELOPMENT%2FAI-WORKPLACE%2Fai-workplace-claudecode"

install-cli-aider:
	pipx install aider-chat[all] --python $(shell which python)
	pipx inject aider-chat google-generativeai
	echo "Use cli command aider"
	echo "Refer: obsidian://open?vault=KB&file=pages%2FDEVELOPMENT%2FAI-WORKPLACE%2Fai-workpace-aider"

install-cli-taskmaster:
	npm install -g task-master-ai
	echo "Use task-master init on a new project"
