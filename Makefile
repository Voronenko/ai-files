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
