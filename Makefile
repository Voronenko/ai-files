SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

clean:
	# Remove old build
	rm -rf ./dist/
	# Ensure target directories exist one level up from .ai-files
	mkdir -p ./dist/.ai-files
	mkdir -p ./dist/.ai-files/skills/
	mkdir -p ./dist/.ai-files/commands/
	mkdir -p ./dist/.roo/commands
	mkdir -p ./dist/.kilocode/workflows
	# claude supports resolving symlinks, only one source
	mkdir -p ./dist/.claude/commands
	# skill directories are shared
	ln -sfn ../.ai-files/skills dist/.kilocode/skills
	ln -sfn ../.ai-files/skills dist/.claude/skills
	# ai-files repo uses own dist
	ln -sfn dist/.kilocode .kilocode
	ln -sfn dist/.claude   .claude
	ln -sfn dist/.roo      .roo
relink-from-dist:
	# ai-files repo uses own dist
	ln -sfn dist/.kilocode .kilocode
	ln -sfn dist/.claude   .claude
	ln -sfn dist/.roo      .roo


prepare-dist: publish-spec-kit publish-memory-bank publish-prompts
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
	cp -r config/claude/* ./dist/.claude/
	cp -r rules ./dist/.ai-files/
	# unified commands (so-called custom prompts)
	cp -r commands ./dist/.ai-files/
	chmod +x ./dist/.specify/scripts/bash/*.sh
	# unified skills
	cp -r skills ./dist/.ai-files/

prepare-claude:
	@mkdir -p ./dist/.claude/commands
	@find ./dist/.ai-files/commands -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.claude/commands/$$(basename "$$f")"; \
		done \
	' sh {} +
	@find ./dist/.ai-files/commands/claude-speckit/ -type f -name '*.md' -exec sh -c '\
		for f do \
			ln -sfr "$$f" "./dist/.claude/commands/$$(basename "$$f")"; \
		done \
	' sh {} +

build: prepare-dist prepare-claude
	echo build completed

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
	@echo "Fetching latest spec-kit release..."
	@LATEST_RELEASE=$$(curl -s https://api.github.com/repos/github/spec-kit/releases/latest | grep '"tag_name"' | cut -d'"' -f4); \
	if [ -z "$$LATEST_RELEASE" ]; then \
		echo "Error: Could not fetch latest release version"; \
		exit 1; \
	fi; \
	echo "Latest release: $$LATEST_RELEASE"; \
	DOWNLOAD_URL="https://github.com/github/spec-kit/releases/download/$$LATEST_RELEASE/spec-kit-template-kilocode-sh-$$LATEST_RELEASE.zip"; \
	CACHE_DIR="./.cache"; \
	CACHE_FILE="$$CACHE_DIR/spec-kit-kilo-$$LATEST_RELEASE.zip"; \
	mkdir -p "$$CACHE_DIR"; \
	\
	# Check if cached version exists \
	if [ -f "$$CACHE_FILE" ]; then \
		echo "Using cached version from $$CACHE_FILE"; \
		cp "$$CACHE_FILE" "./dist/spec-kit-kilo.zip"; \
	else \
		echo "Downloading from: $$DOWNLOAD_URL"; \
		curl -L -o "./dist/spec-kit-kilo.zip" "$$DOWNLOAD_URL"; \
		if [ $$? -ne 0 ]; then \
			echo "Error: Failed to download spec-kit template"; \
			exit 1; \
		fi; \
		# Cache the downloaded file \
		cp "./dist/spec-kit-kilo.zip" "$$CACHE_FILE"; \
	fi; \
	\
	echo "Extracting .kilocode/ contents..."; \
	cd ./dist && unzip -q -o spec-kit-kilo.zip ".kilocode/*" && rm spec-kit-kilo.zip; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to extract spec-kit template"; \
		exit 1; \
	fi; \
	echo "✅ Successfully extracted .kilocode/ contents to ./dist/.kilocode/"

publish-spec-kit-roo:
	@echo "Fetching latest spec-kit release..."
	@LATEST_RELEASE=$$(curl -s https://api.github.com/repos/github/spec-kit/releases/latest | grep '"tag_name"' | cut -d'"' -f4); \
	if [ -z "$$LATEST_RELEASE" ]; then \
		echo "Error: Could not fetch latest release version"; \
		exit 1; \
	fi; \
	echo "Latest release: $$LATEST_RELEASE"; \
	DOWNLOAD_URL="https://github.com/github/spec-kit/releases/download/$$LATEST_RELEASE/spec-kit-template-roo-sh-$$LATEST_RELEASE.zip"; \
	CACHE_DIR="./.cache"; \
	CACHE_FILE="$$CACHE_DIR/spec-kit-roo-$$LATEST_RELEASE.zip"; \
	mkdir -p "$$CACHE_DIR"; \
	\
	# Check if cached version exists \
	if [ -f "$$CACHE_FILE" ]; then \
		echo "Using cached version from $$CACHE_FILE"; \
		cp "$$CACHE_FILE" "./dist/spec-kit-roo.zip"; \
	else \
		echo "Downloading from: $$DOWNLOAD_URL"; \
		curl -L -o "./dist/spec-kit-roo.zip" "$$DOWNLOAD_URL"; \
		if [ $$? -ne 0 ]; then \
			echo "Error: Failed to download spec-kit roo template"; \
			exit 1; \
		fi; \
		# Cache the downloaded file \
		cp "./dist/spec-kit-roo.zip" "$$CACHE_FILE"; \
	fi; \
	\
	echo "Extracting .roo/ contents..."; \
	cd ./dist && unzip -q -o spec-kit-roo.zip ".roo/*" && rm spec-kit-roo.zip; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to extract spec-kit roo template"; \
		exit 1; \
	fi; \
	echo "✅ Successfully extracted .roo/ contents to ./dist/.roo/"

publish-spec-kit-claude:
	@echo "Fetching latest spec-kit release..."
	@LATEST_RELEASE=$$(curl -s https://api.github.com/repos/github/spec-kit/releases/latest | grep '"tag_name"' | cut -d'"' -f4); \
	if [ -z "$$LATEST_RELEASE" ]; then \
		echo "Error: Could not fetch latest release version"; \
		exit 1; \
	fi; \
	echo "Latest release: $$LATEST_RELEASE"; \
	DOWNLOAD_URL="https://github.com/github/spec-kit/releases/download/$$LATEST_RELEASE/spec-kit-template-claude-sh-$$LATEST_RELEASE.zip"; \
	CACHE_DIR="./.cache"; \
	CACHE_FILE="$$CACHE_DIR/spec-kit-claude-$$LATEST_RELEASE.zip"; \
	mkdir -p "$$CACHE_DIR"; \
	\
	# Check if cached version exists \
	if [ -f "$$CACHE_FILE" ]; then \
		echo "Using cached version from $$CACHE_FILE"; \
		cp "$$CACHE_FILE" "./dist/spec-kit-claude.zip"; \
	else \
		echo "Downloading from: $$DOWNLOAD_URL"; \
		curl -L -o "./dist/spec-kit-claude.zip" "$$DOWNLOAD_URL"; \
		if [ $$? -ne 0 ]; then \
			echo "Error: Failed to download spec-kit claude template"; \
			exit 1; \
		fi; \
		# Cache the downloaded file \
		cp "./dist/spec-kit-claude.zip" "$$CACHE_FILE"; \
	fi; \
	\
	echo "Extracting .claude/commands/ contents..."
	rm -rf ./dist/.ai-files/commands/claude-speckit/
	mkdir -p ./dist/.ai-files/commands/claude-speckit/
	cd ./dist && unzip -q -o spec-kit-claude.zip ".claude/commands/*" -d .ai-files/commands/claude-speckit/ && rm spec-kit-claude.zip; \
	mv .ai-files/commands/claude-speckit/.claude/commands/* .ai-files/commands/claude-speckit/ && rm -rf .ai-files/commands/claude-speckit/.claude/; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to extract spec-kit claude template"; \
		exit 1; \
	fi; \
	echo "✅ Successfully extracted .claude/commands/ contents to ./dist/.ai-files/commands/claude-speckit/"

publish-spec-kit: publish-spec-kit-kilo publish-spec-kit-roo publish-spec-kit-claude publish-spec-kit-templates
	@echo ""
	@echo "🎉 All spec-kit templates have been successfully processed!"
	@echo "📦 Summary:"
	@echo "   • .kilocode/ workflows extracted to ./dist/.kilocode/"
	@echo "   • .roo/ commands extracted to ./dist/.roo/"
	@echo "   • .claude/ commands extracted to ./dist/.claude/"
	@echo "   • .specify/ templates extracted to ./dist/.specify/"
	@echo ""
	@echo "✨ All four spec-kit templates are now ready for use!"

publish-spec-kit-templates:
	@echo "Fetching latest spec-kit release..."
	@LATEST_RELEASE=$$(curl -s https://api.github.com/repos/github/spec-kit/releases/latest | grep '"tag_name"' | cut -d'"' -f4); \
	if [ -z "$$LATEST_RELEASE" ]; then \
		echo "Error: Could not fetch latest release version"; \
		exit 1; \
	fi; \
	echo "Latest release: $$LATEST_RELEASE"; \
	DOWNLOAD_URL="https://github.com/github/spec-kit/releases/download/$$LATEST_RELEASE/spec-kit-template-kilocode-sh-$$LATEST_RELEASE.zip"; \
	echo "Downloading from: $$DOWNLOAD_URL"; \
	mkdir -p ./dist; \
	curl -L -o "./dist/spec-kit-templates.zip" "$$DOWNLOAD_URL"; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to download spec-kit templates"; \
		exit 1; \
	fi; \
	echo "Extracting .specify/ contents..."; \
	cd ./dist && \
	if [ -L .specify ]; then \
		echo "Removing existing .specify symlink..."; \
		rm .specify; \
	fi; \
	unzip -q -o spec-kit-templates.zip ".specify/*" && rm spec-kit-templates.zip; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to extract spec-kit templates"; \
		exit 1; \
	fi; \
	echo "✅ Successfully extracted .specify/ contents to ./dist/.specify/"

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
	@mkdir -p ./dist/.roo/rules/memory-bank
	@mkdir -p ./dist/.kilocode/rules/memory-bank
	@echo "Copying memory bank instructions to agent directories..."
	@cp "prompts/memory-bank-instructions.md" "./dist/.roo/rules/memory-bank/"
	@cp "prompts/memory-bank-instructions.md" "./dist/.kilocode/rules/memory-bank/"
	@echo "✅ Memory bank successfully published to all agent directories:"
	@echo "   • ./dist/.roo/rules/memory-bank/"
	@echo "   • ./dist/.kilocode/rules/memory-bank/"


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

install-antigravity-apt:
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
		sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
	echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
		sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
	sudo apt update
	sudo apt install antigravity

install-ai-goose:
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
