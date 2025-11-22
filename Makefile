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

clean:
	# Remove old build
	rm -rf ./dist/
	# Ensure target directories exist one level up from .ai-files
	mkdir -p dist/.roo/commands
	mkdir -p dist/.kilocode/workflows
	mkdir -p dist/.claude/commands
	mkdir -p ./dist/.ai-files

build: publish-spec-kit publish-memory-bank
	mkdir -p ./dist/.ai-files
	cp -r plugins ./dist/.ai-files/
	@echo "Copying and linking plugin files..."
	cp update.sh ./dist/.ai-files/


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

publish-spec-kit-kilo:
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
	curl -L -o "./dist/spec-kit-kilo.zip" "$$DOWNLOAD_URL"; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to download spec-kit template"; \
		exit 1; \
	fi; \
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
	echo "Downloading from: $$DOWNLOAD_URL"; \
	mkdir -p ./dist; \
	curl -L -o "./dist/spec-kit-roo.zip" "$$DOWNLOAD_URL"; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to download spec-kit roo template"; \
		exit 1; \
	fi; \
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
	echo "Downloading from: $$DOWNLOAD_URL"; \
	mkdir -p ./dist; \
	curl -L -o "./dist/spec-kit-claude.zip" "$$DOWNLOAD_URL"; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to download spec-kit claude template"; \
		exit 1; \
	fi; \
	echo "Extracting .claude/ contents..."; \
	cd ./dist && unzip -q -o spec-kit-claude.zip ".claude/*" && rm spec-kit-claude.zip; \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to extract spec-kit claude template"; \
		exit 1; \
	fi; \
	echo "✅ Successfully extracted .claude/ contents to ./dist/.claude/"

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
	@curl -s -o "rules/memory-bank-instructions.md" "https://kilo.ai/docs/downloads/memory-bank.md"
	@if [ $$? -ne 0 ]; then \
		echo "Error: Failed to download memory bank file"; \
		exit 1; \
	fi
	@echo "Processing memory bank file..."
	@sed -i 's/\.kilocode\//\.ai-files\//g' "rules/memory-bank-instructions.md"
	@sed -i 's/Kilo Code/AI FILES/g' "rules/memory-bank-instructions.md"
	@echo "✅ Memory bank successfully downloaded and updated to rules/memory-bank-instructions.md"

publish-memory-bank:
	@echo "Publishing memory bank instructions to all agents..."
	@if [ ! -f "rules/memory-bank-instructions.md" ]; then \
		echo "Error: Memory bank file not found. Run 'make update-memory-bank' first."; \
		exit 1; \
	fi
	@echo "Creating memory bank directories for each agent..."
	@mkdir -p ./dist/.roo/rules/memory-bank
	@mkdir -p ./dist/.kilocode/rules/memory-bank
	@echo "Copying memory bank instructions to agent directories..."
	@cp "rules/memory-bank-instructions.md" "./dist/.roo/rules/memory-bank/"
	@cp "rules/memory-bank-instructions.md" "./dist/.kilocode/rules/memory-bank/"
	@echo "✅ Memory bank successfully published to all agent directories:"
	@echo "   • ./dist/.roo/rules/memory-bank/"
	@echo "   • ./dist/.kilocode/rules/memory-bank/"
