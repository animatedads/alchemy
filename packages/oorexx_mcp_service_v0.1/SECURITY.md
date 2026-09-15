# Security

- MCP `clientInfo` is never trusted as identity or authority.
- The default `McpContextPrincipalResolver` accepts only `request.context['mcp.principal']`, which must be populated by a trusted HTTPS authentication interceptor/gateway.
- HTTPS v0.4.4 may require client certificates for admission, but certificate-to-project-principal mapping remains an application authentication concern; this module does not infer an identity from peer address or self-asserted headers.
- State-changing and request-reading operations fail closed without an authenticated principal.
- Component IDs are checked against the supplied ooRexxAPI catalogue.
- Gopher sphere IDs are restricted to alphanumeric, `.`, `_`, `-` before constructing a local command. Configured paths are local trusted configuration and apostrophes are rejected by the command adapter.
- `Mcp-Method` / `Mcp-Name` / protocol-version headers must agree with the MCP body.
- Replies and read receipts append evidence; they do not mutate historical requests.
- Ownership cannot be silently stolen in v0.1.

The JSONL journal is not a cross-process transaction system. Operate it with one authoritative writer or replace the journal backend with a shared transactional service before horizontally scaling state writers.
