# Provenance

Qualification inputs supplied on 2026-09-08:

- `oorexxapis(20260908-080803).zip` SHA-256 `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`
- `sphere(20260908-080803).zip` SHA-256 `293cd2a62e04965e7c87134902d0509bb453cbe36618f895444a0af7465fc177`
- `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20260908-080830).deb` SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

Consumed heads from the API roll-up:

- HTTPS Server `oorexx_https_server_v0.4.4.zip` SHA-256 `aad4305c2495b13145a71938c59af86bc8d128be8d466aaf7b3548468a252d56`
- Wire UI Server `wire_ui_server_v0.17.zip` SHA-256 `82c3a9d270d123dcbedabed1b57ed5e0944b828b1a184a5b71d47d9f9f188441`
- LLM Gopher `llm_gopher_v0.21-dev1.zip` SHA-256 `6fc0114f730a64470a4e4a819832f933bfc5e628af19bb8b920d860b205fe477`

`catalog/components.json` contains the exact SHA-256 of every top-level `current/*.zip` component captured from that API roll-up.

Primary MCP protocol behavior targets specification revision `2026-07-28`. v0.2-dev2 also serves initialize-era revisions 2025-03-26, 2025-06-18 and 2025-11-25 in stateless compatibility mode for connector interoperability; no Mcp-Session-Id is minted and application authority remains outside MCP identity.

- v0.2-dev2 live-binding correction: `McpHttpsRoute.cls` imports `https_server.cls` directly; qualification reproduces the v0.2-dev1 sibling-package `.HttpResponse` failure and passes with the real HTTPS v0.4.4 class.

- v0.2-dev3 MCP JSON wire correction: tool input schemas now use `.json~false` for `additionalProperties`, and tool-call booleans use JSONBoolean sentinels. This fixes strict ChatGPT connector schema rejection caused by v0.2-dev2 serializing Rexx `.false` as numeric `0`.

- v0.2-dev4 ownership lifecycle correction: adds `PROJECT.OWNERSHIP.RELEASE` / `project.ownership.release` after live ChatGPT qualification showed that active claims had no inverse operation. Release is owner-only, idempotent when already unowned, append-only in the journal, and permits a subsequent clean claim by another principal.

- v0.2-dev5 connector-name isolation: after Grok could directly initialize, list and call the live MCP service but its connected-tool index exposed zero Alchemy tools, the adapter gained an optional `compat` tool-name presentation. It advertises eight underscore aliases only and shares the same Wire semantic service. Canonical dotted names remain authoritative. Tool schemas also omit the optional `$schema` member to reduce client-validator surface. A real TLS qualification bound `/mcp` and `/mcp-compat` simultaneously and observed 8 canonical versus 8 alias tools. GET remains 405 because the service is stateless; no fake SSE transport is introduced.

- v0.2-dev6 xAI protocol-routing correction: a live xAI Responses API probe against `/mcp-compat` failed before `tools/list` with `-32020 Unsupported MCP protocol version: 2025-11-25`. The cause was that the adapter routed any request carrying `MCP-Protocol-Version` to the 2026 modern path. Streamable-HTTP initialize-era clients legitimately carry the negotiated legacy version header on later requests. The adapter now routes by version value, accepts 2025-11-25/2025-06-18/2025-03-26 headers on the legacy tool path, checks matching initialize header/body versions, and retains explicit rejection of unknown versions. `test_mcp_xai_streamable_http.rex` locks the observed xAI sequence.

- v0.2-dev8 first-class sphere ownership: live Claude qualification exposed that a sphere could be resolved by Gopher but was absent from the project component/ownership catalogue, forcing an LLM to consider claiming the much broader `llm_gopher` runtime merely to own one authored sphere. The catalogue is now composite: 82 runtime/API artifact entries plus 53 sphere artifact entries from the supplied sphere roll-up, representing 129 unique canonical component IDs. Sphere components use `sphere:<gopher-sphere-id>`; ownership, requests, mailboxes, receipts and release work identically for both kinds. `oorexx_llm_pitfalls` resolves as a compatibility alias to `sphere:oorexx-llm-pitfalls`, while exact runtime IDs win over colliding aliases. Grok live qualification also confirmed dev6 xAI interoperability: all eight compatibility tools became available and `project_components_list` / `project_requests_list` executed successfully.

## v0.2-dev8 qualification authority integration

Optional qualification control is grounded against `qualification_execution_broker_v0.1-dev1.zip` SHA-256 `ecbd9419343f11e96e112679fd0a1f54308c2bb293a849d6de613d40cac7487f`. The MCP adapter adds seven control/evidence tools only when that broker is injected. The tool surface contains no worker execute transition and no private-key field. Qualification signing uses public verification key identities plus detached signatures; the private key remains local to the human authorization utility.
