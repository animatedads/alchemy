# ooRexx MCP Project Service v0.1

An MCP 2026-07-28 adapter for the existing ooRexx HTTPS and Wire service architecture.

The module does **not** make MCP authoritative for project state. The MCP protocol adapter terminates MCP JSON-RPC, the ooRexx HTTPS server owns transport/TLS, and `McpProjectWireService` owns project coordination semantics using the same `WireUIResult` success/failure contract as Wire UI Server.

## Initial tools

- `sphere.check` — resolve/check a named LLM Gopher sphere and return provenance.
- `project.components.list` — list current ooRexxAPI components, ownership and request counts.
- `project.request.create` — create an immutable project request. If `recipientId` is omitted, the current owner is selected; if unowned, the request is held in `component:<componentId>`.
- `project.ownership.claim` — claim the one active ownership record for a component.
- `project.requests.list` — list requests visible to the authenticated principal, optionally unread only.
- `project.request.mark_read` — append a per-reader receipt without modifying the request.
- `project.request.reply` — create a new request whose `parentRequestId` points to the request being answered and whose `rootRequestId` preserves the chain root.

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
       +-- component catalogue (ooRexxAPI snapshot)
       +-- append-only project journal
       +-- LLM Gopher sphere checker
```

`clientInfo` is display/diagnostic metadata and is never authority. A trusted HTTPS authentication interceptor or gateway must put the verified principal into `request.context['mcp.principal']`. The default route resolver fails closed when that context value is absent.

## Persistence

Project coordination is event-sourced. `McpProjectJsonlJournal` appends immutable JSONL events and service startup replays them. v0.1 is a **single-writer journal backend**. MCP itself remains stateless, but multiple MCP adapters must route state-changing operations to one authoritative Wire service instance unless a shared transactional journal backend is supplied later.

## Component catalogue

`catalog/components.json` is generated from the exact top-level `current/*.zip` heads in `oorexxapis(20260908-080803).zip`. Requests and ownership claims fail closed for component IDs absent from this catalogue.

## Wiring

Add these directories to `REXX_PATH`:

- this package `src/`
- this package `integration/`
- Wire UI Server v0.17 `src/`
- ooRexx 5.3.0 `bin/` (for `json.cls`)
- HTTPS Server v0.4.4 `rexx/` and its normal dependencies when launching the HTTPS server

Construct the catalogue, journal, optional Gopher checker, project service, protocol adapter and HTTPS route. See `examples/embed_mcp.rex`.

## Qualification

Run `./run_tests.sh`. Set `MCP_GOPHER`, `MCP_API_ROLLUP` and `MCP_SPHERE_OVERRIDE_DIR` to enable the live Gopher integration test. The delivered qualification was run against the supplied ooRexx 5.3.0 r13196 build and current Wire/Gopher/API artefacts; see `VALIDATION.txt` and `PROVENANCE.md`.
