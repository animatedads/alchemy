# Security

- MCP `clientInfo` is never trusted as identity or authority.
- The default `McpContextPrincipalResolver` accepts only `request.context['mcp.principal']`, which must be populated by a trusted HTTPS authentication interceptor/gateway.
- HTTPS v0.4.4 may require client certificates for admission, but certificate-to-project-principal mapping remains an application authentication concern; this module does not infer an identity from peer address or self-asserted headers.
- State-changing and request-reading operations fail closed without an authenticated principal.
- Component IDs are checked against the sealed composite catalogue sourced from the supplied ooRexxAPI and sphere roll-ups. Sphere ownership uses canonical `sphere:<sphereId>` IDs so it cannot overwrite a same-named runtime ownership record. Exact component IDs take precedence over aliases.
- Gopher sphere IDs are restricted to alphanumeric, `.`, `_`, `-` before constructing a local command. Configured paths are local trusted configuration and apostrophes are rejected by the command adapter.
- `Mcp-Method` / `Mcp-Name` / protocol-version headers must agree with the MCP body.
- Replies and read receipts append evidence; they do not mutate historical requests.
- Ownership cannot be silently stolen. Only the authenticated active owner may release its claim; release is append-only evidence and never transfers ownership implicitly.

The JSONL journal is not a cross-process transaction system. Operate it with one authoritative writer or replace the journal backend with a shared transactional service before horizontally scaling state writers.

## Wire type integrity

MCP schemas and results use JSONBoolean sentinels for protocol/schema boolean members. Rexx logical `0`/`1` values must not be emitted directly where the MCP or JSON Schema contract requires JSON `false`/`true`; strict clients may reject such wire data before any tool executes.


## Compatibility aliases

The underscore compatibility endpoint does not create a weaker authority path.  Alias
resolution occurs only after the same MCP envelope validation and then reaches the same
`McpProjectWireService`; authenticated principal requirements are identical.  Hosts
should bind `/mcp-compat` only when testing or supporting a client that needs it.

## Protocol-version routing

Protocol-version compatibility does not alter identity or authorization. Initialize-era version headers select only the wire parser/response shape; authenticated HTTPS `mcp.principal` remains the sole authority for protected project operations. Unknown versions and mismatched initialize header/body versions fail closed.
