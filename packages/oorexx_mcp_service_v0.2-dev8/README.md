# ooRexx MCP Project Service v0.2-dev8

An MCP 2026-07-28 adapter for the existing ooRexx HTTPS and Wire service architecture.

The module does **not** make MCP authoritative for project state. The MCP protocol adapter terminates MCP JSON-RPC, the ooRexx HTTPS server owns transport/TLS, and `McpProjectWireService` owns project coordination semantics using the same `WireUIResult` success/failure contract as Wire UI Server.

## Canonical tools

- `sphere.check` — resolve/check a named LLM Gopher sphere and return provenance.
- `project.components.list` — list first-class project components (runtime/API and Gopher sphere components), ownership and request counts. Optional `componentKind` filters to `runtime` or `sphere`.
- `project.request.create` — create an immutable project request. If `recipientId` is omitted, the current owner is selected; if unowned, the request is held in `component:<componentId>`.
- `project.ownership.claim` — claim the one active ownership record for a component.
- `project.ownership.release` — release active ownership. Only the authenticated current owner may release it; the release is append-only evidence and the component becomes claimable again.
- `project.requests.list` — list requests visible to the authenticated principal, optionally unread only.
- `project.request.mark_read` — append a per-reader receipt without modifying the request.
- `project.request.reply` — create a new request whose `parentRequestId` points to the request being answered and whose `rootRequestId` preserves the chain root.


## First-class sphere components (v0.2-dev8)

The project ownership/request catalogue now includes Gopher spheres as **components**, rather than treating them only as files discoverable through `sphere.check`. The supplied snapshots produce 135 catalogue entries: 82 runtime/API artifact entries plus 53 sphere artifact entries, representing 129 unique canonical component IDs.

Sphere components use the collision-safe canonical form `sphere:<gopher-sphere-id>`. For example, the supplied `oorexx_llm_pitfalls_sphere_v0.1.zip` is the component `sphere:oorexx-llm-pitfalls`. Requests, ownership claims/releases, unread counts and component mailboxes work identically for sphere and runtime components. Runtime exact IDs always win over convenience aliases, so `civicport` remains the runtime component while `sphere:civicport` names the knowledge sphere.

Convenience aliases preserve common existing spellings when they resolve unambiguously. In particular `oorexx_llm_pitfalls` resolves to `sphere:oorexx-llm-pitfalls`. Journal events always store the canonical component ID. `sphere.check` may be given the sphere component ID as `componentId`; if its `sphereId` does not match that component, the service fails with `SPHERE_COMPONENT_MISMATCH` before invoking Gopher.

`catalog/runtime_components.json` and `catalog/sphere_components.json` are provenance-separated snapshots. `tools/build_sphere_catalog.py` projects a sphere roll-up into sphere components and `tools/build_combined_catalog.py` composes the runtime and sphere catalogues. These are build-time utilities only; the runtime reads the sealed `catalog/components.json`.

## xAI Streamable-HTTP negotiation correction (v0.2-dev6)

xAI Remote MCP was observed reaching `/mcp-compat`, negotiating `2025-11-25`, and then sending `MCP-Protocol-Version: 2025-11-25` on subsequent `tools/list` requests. Earlier adapters treated the mere presence of that header as evidence of the 2026 stateless protocol and rejected the request with `-32020 Unsupported MCP protocol version`.

v0.2-dev6 routes by the **header value**, not by header presence: `2026-07-28` enters the modern path; explicit initialize-era versions `2025-11-25`, `2025-06-18`, and `2025-03-26` remain on the initialize-era Streamable-HTTP tool path. A matching legacy header is also accepted on `initialize`; mismatched or unknown versions still fail closed.

## Grok compatibility presentation (v0.2-dev5)

The project API remains the eight canonical dotted MCP tool names above.  v0.2-dev5
adds an **optional second MCP presentation** for clients whose connector index may
reject or mishandle dotted tool identifiers.  Construct a second
`McpProtocolAdapter` with tool-name mode `compat` and bind it to a separate path,
for example `/mcp-compat`.  It advertises exactly the same eight semantic operations
under conservative underscore aliases:

- `sphere_check`
- `project_components_list`
- `project_request_create`
- `project_ownership_claim`
- `project_ownership_release`
- `project_requests_list`
- `project_request_mark_read`
- `project_request_reply`

The canonical adapter also accepts these aliases when called, but does not advertise
them.  The compatibility adapter advertises aliases only, so a connector that rejects
the whole tool list because of dotted names can be tested without changing project
semantics or polluting the canonical surface.

All advertised input schemas now use the deliberately small common subset needed by
this service (`type`, `properties`, `required`, `additionalProperties`) and omit the
optional top-level `$schema` declaration.

`GET /mcp` remains HTTP 405 by design.  This service is stateless and has no
unsolicited server-to-client stream.  The MCP SDK guidance for stateless Streamable
HTTP likewise leaves GET unavailable; v0.2-dev5 therefore does **not** fake an SSE
stream merely to satisfy a connector probe.  A real stateful/SSE transport would
require session and streaming support rather than a one-shot compatibility response.

## Authority model

```text
MCP client / LLM
       |
       | MCP 2026-07-28 JSON-RPC
       v
ooRexx HTTPS Server v0.4.4
       |
       | authenticated request context
       v
McpHttpsRoute / McpProtocolAdapter
       |
       | semantic operation
       v
McpProjectWireService
       |
       +-- component catalogue (ooRexxAPI + Gopher sphere snapshots)
       +-- append-only project journal
       +-- LLM Gopher sphere checker
```

`clientInfo` is display/diagnostic metadata and is never authority. A trusted HTTPS authentication interceptor or gateway must put the verified principal into `request.context['mcp.principal']`. The default route resolver fails closed when that context value is absent.

## Persistence

Project coordination is event-sourced. `McpProjectJsonlJournal` appends immutable JSONL events and service startup replays them. v0.1 is a **single-writer journal backend**. MCP itself remains stateless, but multiple MCP adapters must route state-changing operations to one authoritative Wire service instance unless a shared transactional journal backend is supplied later.

## Component catalogue

`catalog/components.json` is the composite project catalogue built from the exact top-level `current/*.zip` heads in `oorexxapis(20260908-080803).zip` and the sphere archives in `sphere(20260908-080803).zip`. Requests and ownership claims fail closed for component IDs absent from this catalogue. Sphere components are namespaced with `sphere:` so executable/runtime and knowledge ownership never collide.

## Wiring

Add these directories to `REXX_PATH`:

- this package `src/`
- this package `integration/`
- Wire UI Server v0.17 `src/`
- ooRexx 5.3.0 `bin/` (for `json.cls`)
- HTTPS Server v0.4.4 `rexx/` and its normal dependencies when launching the HTTPS server

Construct the catalogue, journal, optional Gopher checker, project service, protocol adapter and HTTPS route. See `examples/embed_mcp.rex`.

## Qualification

Run `./run_tests.sh` with `WIRE_UI_SERVER_HOME`, `HTTPS_SERVER_HOME` and `FOREIGN_RUNTIME_HOME` pointing at the unpacked qualified dependencies. Set `MCP_GOPHER`, `MCP_API_ROLLUP` and `MCP_SPHERE_OVERRIDE_DIR` to enable the live Gopher integration test. The delivered qualification was run against the supplied ooRexx 5.3.0 r13196 build and current Wire/Gopher/API artefacts; see `VALIDATION.txt` and `PROVENANCE.md`.

## ChatGPT connector compatibility (v0.2-dev3)

### JSON Schema / JSON boolean wire correction (v0.2-dev3)

The ooRexx JSON package intentionally distinguishes Rexx logical values (`0`/`1`)
from JSON booleans.  v0.2-dev2 used `.false` for `inputSchema.additionalProperties`,
which serialized as the JSON number `0`.  JSON Schema 2020-12 requires that member
to be either a boolean or a schema object, so strict MCP clients such as ChatGPT
rejected the first advertised tool with `Invalid MCP tool schema for tool
'sphere.check'`.

v0.2-dev3 emits `.json~false`, producing the required literal `false`.  The same
wire-typing audit also corrects `tools/call` `isError` and `structuredContent.ok`
to emit JSON booleans (`true`/`false`) rather than JSON numbers (`1`/`0`).
The qualification suite checks the raw serialized JSON, not merely Rexx logical
equality after parsing.


The primary wire contract remains MCP `2026-07-28`.  The HTTP adapter now also
accepts initialize-era MCP clients (`2025-03-26`, `2025-06-18`, and
`2025-11-25`) in stateless compatibility mode.  This is deliberate deployment
compatibility for hosts whose connector scanners have not yet moved to the
2026 stateless lifecycle; it does not reintroduce protocol session authority.

`GET /mcp` and `HEAD /mcp` are operator probes only and return HTTP 405 with
`Allow: POST`.  Actual MCP traffic is `POST /mcp`.

For an initial ChatGPT tool-scan test use **No authentication**.  Write-capable
project tools still fail closed without a trusted HTTPS interceptor placing
`mcp.principal` into `HttpExchangeContext`; no MCP `clientInfo` value grants
project authority.

See `tools/probe_mcp.sh` for modern and initialize-era deployment probes.

### HTTPS package-binding correction

`McpHttpsRoute.cls` now directly `::requires 'https_server.cls'`.  This is
necessary in ooRexx because a public class exported by one required package is
not automatically visible inside an unrelated sibling required package.  The
previous contract-fake test masked that boundary: a host could load the HTTPS
server successfully while `.HttpResponse` inside `McpHttpsRoute.cls` still
resolved as an unresolved environment symbol, producing an application-level
500 when the route tried to construct its response.  v0.2-dev2 qualifies the
route against the real HTTPS v0.4.4 `HttpResponse` class.


## Ownership release (v0.2-dev4)

`project.ownership.release` closes the first gap found by live external-client qualification. Ownership remains event-sourced: release appends an `OWNERSHIP_RELEASED` event and removes only the active projection. The historical claim and release remain in the journal. A non-owner cannot release another principal's claim; releasing an already-unowned component is idempotent (`ALREADY_UNOWNED`); and a released component can be claimed by another authenticated principal.

## Connector-name isolation (v0.2-dev5)

Live Grok qualification showed a useful split: direct MCP `initialize`, `tools/list`
and `tools/call` all succeeded against the public server, while Grok's connected-tool
index imported zero project tools.  v0.2-dev5 provides `/mcp-compat` as an A/B test
surface containing only underscore identifiers.  If Grok imports that surface, the
client's tool-name indexing is implicated; if it still imports zero tools while direct
MCP calls succeed, the failure is beyond the ooRexx MCP protocol/service path.

## Qualification Execution Broker integration (v0.2-dev8)

When a `QualificationExecutionBroker` instance is supplied to `McpProtocolAdapter`, the service advertises seven additional tools: `qualification.plan`, `qualification.request`, `qualification.authorization.challenge`, `qualification.authorization.submit`, `qualification.status`, `qualification.results`, and `qualification.cancel` (underscore aliases on the compatibility endpoint). Existing deployments with no broker continue to advertise the original eight project tools.

The qualification control plane is preflight-first. The server resolves operator-controlled artifact/data/runtime/sandbox/test-plan/target identities and proves runnability before freezing an intent or asking the human to sign. Only the detached signature and public-key identity return through MCP. The private signing key is local-only and is not represented by any MCP field. There is deliberately no `qualification.execute` tool: execution transition belongs to the qualification worker after pre-execution revalidation.
