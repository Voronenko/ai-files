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
	mkdir -p ./dist/.ai-files/dotroo/commands
	mkdir -p ./dist/.ai-files/dotkilo/commands
	# claude supports resolving symlinks, only one source
	mkdir -p ./dist/.ai-files/dotclaude/commands
	# skill directories are shared (symlinks within dot* dirs point to ../skills/ which is dist/.ai-files/skills/)
	ln -sfn ../skills dist/.ai-files/dotkilo/skills
	ln -sfn ../skills dist/.ai-files/dotclaude/skills
	# create symlinks from hidden names to visible directories (relative symlinks)
	ln -sfn .ai-files/dotkilo dist/.kilo
	ln -sfn .ai-files/dotclaude dist/.claude
	ln -sfn .ai-files/dotroo dist/.roo
	ln -sfn .ai-files/dotspecify dist/.specify
	# ai-files repo uses own dist
	ln -sfn dist/.kilo .kilo
	ln -sfn dist/.claude   .claude
	ln -sfn dist/.roo      .roo
relink-from-dist:
	# create symlinks from hidden names to visible directories (relative symlinks)
	ln -sfn .ai-files/dotkilo dist/.kilo
	ln -sfn .ai-files/dotclaude dist/.claude
	ln -sfn .ai-files/dotroo dist/.roo
	ln -sfn .ai-files/dotspecify dist/.specify
	# ai-files repo uses own dist
	ln -sfn dist/.kilo .kilo
	ln -sfn dist/.claude   .claude
	ln -sfn dist/.roo      .roo


prepare-dist: publish-spec-kit publish-commands publish-memory-bank publish-prompts
	mkdir -p ./dist/.ai-files
	cp -r plugins ./dist/.ai-files/
	@echo "Copying and linking plugin files..."
        # updating utility
	cp update.sh ./dist/.ai-files/
        # unified stub for AGENTS.md
	cp AGENTS.md ./dist/
	# redirector for claude code to use AGENTS.md
	cp CLAUDE.md ./dist/
	# instructions for more efficient tools using
	cp COMMON_CODE_TASKS.md ./dist/.ai-files/
	# clause specific configs
	cp -r config/claude/* ./dist/.ai-files/dotclaude/
	cp -r rules ./dist/.ai-files/
	# unified skills
	cp -r skills ./dist/.ai-files/
	# Makefile for dist operations
	cp Makefile.dist ./dist/Makefile
	# gitignore for dist
	cp dotignore.local.dist ./dist/dotignore.local
	# roaming files list for worktree setup
	@echo "Creating roaming-files.txt..."
	@echo ".mcp.json" > ./dist/.ai-files/roaming-files.txt
	@echo "AGENTS.md" >> ./dist/.ai-files/roaming-files.txt
	@echo "CLAUDE.md" >> ./dist/.ai-files/roaming-files.txt

prepare-claude:
	@mkdir -p ./dist/.ai-files/dotclaude/commands
	@find ./dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.ai-files/dotclaude/commands/$$(basename "$$f")"; \
		done \
	' sh {} +
	@echo "✅ Created symlinks to ./dist/.ai-files/dotclaude/commands/"

build: prepare-dist prepare-claude create-symlinks
	echo build completed

create-symlinks:
	@echo "Creating symlinks..."
	@ln -sfn .ai-files/dotkilo dist/.kilo
	@ln -sfn .ai-files/dotclaude dist/.claude
	@ln -sfn .ai-files/dotroo dist/.roo
	@ln -sfn .ai-files/dotspecify dist/.specify
	@ln -sfn dist/.kilo .kilo
	@ln -sfn dist/.claude .claude
	@ln -sfn dist/.roo .roo
	@echo "✅ Symlinks created"

publish-prompts:
	mkdir -p ./dist/.ai-files/prompts
	cp -r ./prompts/ ./dist/.ai-files


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

publish-spec-kit-roo:
	@echo "Creating symlinks for roo commands..."
	@mkdir -p ./dist/.ai-files/dotroo/commands; \
	find ./dist/.ai-files/commands/speckit -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.ai-files/dotroo/commands/$$(basename "$$f")"; \
		done \
	' sh {} +; \
	echo "✅ Successfully created symlinks to ./dist/.ai-files/dotroo/commands/"

publish-commands-roo:
	@echo "Creating symlinks for non-speckit commands to roo..."
	@mkdir -p ./dist/.ai-files/dotroo/commands; \
	find ./dist/.ai-files/commands -maxdepth 1 -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.ai-files/dotroo/commands/$$(basename "$$f")"; \
		done \
	' sh {} +; \
	echo "✅ Successfully created symlinks to ./dist/.ai-files/dotroo/commands/"

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

publish-spec-kit: publish-spec-kit-templates publish-spec-kit-roo publish-spec-kit-kilo publish-spec-kit-claude
	@echo ""
	@echo "🎉 All spec-kit templates have been successfully processed!"
	@echo "📦 Summary:"
	@echo "   • .kilo/ commands linked to ./dist/.ai-files/dotkilo/"
	@echo "   • .roo/ commands linked to ./dist/.ai-files/dotroo/"
	@echo "   • .claude/ skills initialized to ./dist/.ai-files/dotclaude/"
	@echo "   • .specify/ templates initialized to ./dist/.ai-files/dotspecify/"
	@echo ""
	@echo "✨ All four spec-kit templates are now ready for use!"

publish-commands-source:
	@echo "Copying commands source to dist..."
	@mkdir -p ./dist/.ai-files
	@cp -r commands ./dist/.ai-files/
	@chmod +x ./dist/.ai-files/dotspecify/scripts/bash/*.sh
	@echo "✅ Commands source copied to ./dist/.ai-files/commands/"

publish-commands: publish-commands-source publish-commands-roo publish-commands-kilo
	@echo ""
	@echo "🎉 All non-speckit commands have been successfully linked!"
	@echo "📦 Summary:"
	@echo "   • workout commands linked to ./dist/.ai-files/dotkilo/commands/"
	@echo "   • workout commands linked to ./dist/.ai-files/dotroo/commands/"
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
	@sed -i 's/\.kilocode\/rules\//\.ai-files\//g' "prompts/memory-bank-instructions.md"
	@sed -i 's/Kilo Code/AI FILES/g' "prompts/memory-bank-instructions.md"
	@echo "✅ Memory bank successfully downloaded and updated to prompts/memory-bank-instructions.md"

publish-memory-bank:
	@echo "Publishing memory bank instructions to all agents..."
	@if [ ! -f "prompts/memory-bank-instructions.md" ]; then \
		echo "Error: Memory bank file not found. Run 'make update-memory-bank' first."; \
		exit 1; \
	fi
	@echo "Creating memory bank directories for each agent..."
	@mkdir -p ./dist/.ai-files/dotroo/rules/memory-bank
	@mkdir -p ./dist/.ai-files/dotkilo/rules/memory-bank
	@echo "Copying memory bank instructions to agent directories..."
	@cp "prompts/memory-bank-instructions.md" "./dist/.ai-files/dotroo/rules/memory-bank/"
	@cp "prompts/memory-bank-instructions.md" "./dist/.ai-files/dotkilo/rules/memory-bank/"
	@echo "✅ Memory bank successfully published to all agent directories:"
	@echo "   • ./dist/.ai-files/dotroo/rules/memory-bank/"
	@echo "   • ./dist/.ai-files/dotkilo/rules/memory-bank/"


## Common tools installation routines

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

install-antigravity-apt:
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
		sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
	echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
		sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
	sudo apt update
	sudo apt install antigravity

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
install-opencode-cli:
	@INSTALL_DIR="$${INSTALL_DIR:-$$HOME/dotfiles/bin}" && \
	mkdir -p "$$INSTALL_DIR" && \
	rm -rf /tmp/opencode-install && \
	mkdir -p /tmp/opencode-install && \
	echo "Installing opencode into $$INSTALL_DIR" && \
	curl -fsSL \
	  https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz \
	  -o /tmp/opencode-install/opencode.tar.gz && \
	tar -xzf /tmp/opencode-install/opencode.tar.gz -C /tmp/opencode-install && \
	install -m 755 /tmp/opencode-install/opencode "$$INSTALL_DIR/opencode" && \
	rm -rf /tmp/opencode-install && \
	echo "opencode installed successfully"

install-gemini-cli:
	npm install -g @google/gemini-cli

install-mcp-memory-service:
	pipx mcp-memory-service
	pipx inject mcp-memory-service onnxruntime

install-cli-to-local-bin:
	@set -e; \
	SRC="$(PWD)/bin/ai-files-cli"; \
	DST="$(HOME)/.local/bin/ai-files-cli"; \
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
