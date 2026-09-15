# Architecture

## Boundaries

### HTTPS owns transport

HTTPS Server v0.4.4 owns TLS, optional mTLS admission, HTTP parsing/framing, request limits, route dispatch and `HttpExchangeContext`. MCP does not open sockets and does not own TLS policy.

### MCP owns protocol translation

`McpProtocolAdapter` implements the MCP 2026-07-28 stateless request envelope for `server/discover`, `tools/list` and `tools/call`. It validates `MCP-Protocol-Version`, `Mcp-Method` and `Mcp-Name` against the body before invoking project semantics.

### Wire owns project semantics

`McpProjectWireService` returns `WireUIResult` and owns component validation, visibility, ownership conflict rules, immutable request chains and read receipts. The protocol adapter cannot edit the journal or catalogue directly.

This is intentionally a semantic Wire service rather than a fake `UI_ACTION`: project coordination is application state, not a rendered UI event. A Wire UI application can later project the same service state for a human operator without changing MCP semantics.

## Request chain

A request is immutable. A reply creates another request:

```text
REQ-00000001
  rootRequestId   = REQ-00000001
  parentRequestId = ""
        |
        +-- REQ-00000005
              rootRequestId   = REQ-00000001
              parentRequestId = REQ-00000001
                    |
                    +-- REQ-00000008
                          rootRequestId   = REQ-00000001
                          parentRequestId = REQ-00000005
```

Read state is separate event evidence (`REQUEST_READ`) keyed by request and reader.

## Component mailbox

A request with no explicit recipient resolves to:

1. current active component owner, if one exists; otherwise
2. `component:<componentId>`.

The active owner is allowed to see the component mailbox. Therefore work can be requested before an LLM takes ownership, and the later owner inherits the outstanding component-addressed requests without rewriting them.

## Ownership

v0.1 permits one ACTIVE owner per component. A claim by the current owner is idempotent. A claim by another principal returns `OWNERSHIP_CONFLICT`; there is no implicit stealing. Transfer/release is deliberately deferred to a later governed operation.

## Journal

Committed state change order is:

```text
validate -> append durable event -> apply event in memory -> return success
```

A failed append cannot publish a successful semantic result. Replay rejects duplicate ownership/request evidence and unsupported/malformed journal schemas.

The supplied JSONL backend is single-writer. The abstraction is intentionally narrow so a Storage Fabric / Queue-backed transactional journal may replace it without changing MCP tools.
