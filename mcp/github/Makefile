claude-user:
	claude mcp add-json github --scope user \
	  '{"command": "~/ai-files/mcp/github/github-mcp-wrapper", "args": ["stdio"]}'
claude-local:
	claude mcp add-json github \
          '{"command": "~/ai-files/mcp/github/github-mcp-wrapper", "args": ["stdio"]}'

kilocode-user:
	mkdir -p ~/.config/VSCodium/User/globalStorage/kilocode.kilo-code/settings
	./configure-mcpjson.sh user

kilocode-local:
	mkdir -p ~/.kilocode
	./configure-mcpjson.sh local
