# Rasen Falcon Operator Console (ooRexx)

Status (2026-11-07): source candidate only; **NOT DEPLOYED or OPERATIONAL**.

This operator-only localhost application lets a human operator inspect Rasen Falcon requests and threaded enquiries and reply or explicitly record a decision. Architecture: native Alchemy Wire UI renderer → WireUIServer v0.17 → Queue Fabric / native browser gateway → RFOperatorWireApplication → RFOperatorMailbox → authenticated native Rasen Falcon MCP client. No Python, Node, fake browser authority or direct HTTP access to MCP credentials.

Development source candidate `rasenfalcon_operator_console_v0.1-dev2.zip` was produced in the ChatGPT project conversation (SHA256 `6a95a92acdba952c425833658a9d6c75b2bcf951729c0ed9cc72cce1646781e9`). This GitHub entry is only an integration handoff; it does **not** represent source publication of the ZIP or a deployed program.

The native ooRexx domain contract requires `principal()`, `requestsList(unreadOnly)`, `markRead(requestId)` and `requestReply(requestId,body,requestType)` returning `.RFOperatorResult` objects. Current MCP backend operations: `project.requests.list`, `project.request.mark_read`, `project.request.reply` from `packages/oorexx_mcp_service_v0.2-dev8`. Caller must be a verified human principal, never the CHATGPT connector. Confirm/decline are append-only request replies, **not** job execution.

Must pass prior to production: operator principal authentication and CA trust, real native HTTPS MCP transport, compiled semantic release, native localhost HTTP/WebSocket access, CSRF/Origin/session expiry, real live request/reply verification, stale duplicate replay and privilege-denial regression tests. No authorisations are sent as part of smoke tests.

Rasen Falcon lane: `rasenfalcon-operator-console`; integration handoff `REQ-00003309`, `REQ-00003317`.