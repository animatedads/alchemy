#!/usr/bin/env bash
set -euo pipefail
BASE="${1:-https://127.0.0.1}"
MCP="${BASE%/}/mcp"
COMPAT="${BASE%/}/mcp-compat"

echo '== operator GET probe (405 expected) =='
curl -ksS -i "$MCP" | sed -n '1,14p'

echo
echo '== MCP 2026-07-28 server/discover =='
curl -ksS -i "$MCP" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2026-07-28' \
  -H 'Mcp-Method: server/discover' \
  --data-binary '{"jsonrpc":"2.0","id":"probe-modern","method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{},"io.modelcontextprotocol/clientInfo":{"name":"oorexx-probe","version":"1.0"}}}}'

echo
echo '== xAI initialize-era 2025-11-25 initialize =='
curl -ksS -i "$COMPAT" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data-binary '{"jsonrpc":"2.0","id":"probe-xai-init","method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"xai-probe","version":"1.0"}}}'

echo
echo '== xAI 2025-11-25 tools/list with negotiated version header =='
curl -ksS -i "$COMPAT" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-11-25' \
  --data-binary '{"jsonrpc":"2.0","id":"probe-xai-tools","method":"tools/list","params":{}}'
