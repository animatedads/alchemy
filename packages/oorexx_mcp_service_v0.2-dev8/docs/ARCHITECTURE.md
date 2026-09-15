# Architecture

## Boundaries

### HTTPS owns transport

HTTPS Server v0.4.4 owns TLS, optional mTLS admission, HTTP parsing/framing, request limits, route dispatch and `HttpExchangeContext`. MCP does not open sockets and does not own TLS policy.

### MCP owns protocol translation

`McpProtocolAdapter` implements the MCP 2026-07-28 stateless request envelope for `server/discover`, `tools/list` and `tools/call`. It validates `MCP-Protocol-Version`, `Mcp-Method` and `Mcp-Name` against the body before invoking project semantics. The default adapter advertises canonical dotted names. An optional `compat` adapter advertises underscore aliases only; both dispatch to the same Wire operations.

### Wire owns project semantics

`McpProjectWireService` returns `WireUIResult` and owns component validation, visibility, ownership conflict rules, immutable request chains and read receipts. The protocol adapter cannot edit the journal or catalogue directly.

This is intentionally a semantic Wire service rather than a fake `UI_ACTION`: project coordination is application state, not a rendered UI event. A Wire UI application can later project the same service state for a human operator without changing MCP semantics.

## Sphere components

The ownership tree is a component graph, not an executable-only list. The composite catalogue projects Gopher sphere archives into first-class components with canonical IDs `sphere:<sphereId>`. This keeps knowledge authorship/maintenance independent from ownership of the runtime component that the sphere may document.

For example:

```text
llm_gopher                 runtime component
sphere:oorexx-llm-pitfalls independent knowledge component
```

Claiming the latter does not claim `llm_gopher`. A sphere component has the same mailbox, request-chain, read-receipt and claim/release semantics as any other component. Exact runtime IDs have precedence over convenience aliases; the explicit `sphere:` namespace is always available for collisions.

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

There is one ACTIVE owner per component. A claim by the current owner is idempotent. A claim by another principal returns `OWNERSHIP_CONFLICT`; there is no implicit stealing. The authenticated active owner may explicitly release ownership. Release appends immutable `OWNERSHIP_RELEASED` evidence, removes only the active ownership projection, and makes the component claimable again. A different principal cannot release the owner's claim, and an already-unowned release is idempotent.

## Journal

Committed state change order is:

```text
validate -> append durable event -> apply event in memory -> return success
```

A failed append cannot publish a successful semantic result. Replay rejects duplicate ownership/request evidence and unsupported/malformed journal schemas.

The supplied JSONL backend is single-writer. The abstraction is intentionally narrow so a Storage Fabric / Queue-backed transactional journal may replace it without changing MCP tools.

## Connector compatibility boundary

Compatibility is intentionally handled at MCP **presentation**, not inside Wire.
A host may bind two adapters sharing one `McpProjectWireService`:

```text
/mcp         -> canonical adapter -> 8 dotted names ----+
                                                      |
/mcp-compat  -> compat adapter    -> 8 aliases --------+--> same Wire service/journal
```

No request, ownership, receipt, or sphere semantics are duplicated.  This makes a
client-name compatibility experiment reversible and prevents client quirks becoming
project authority.  Stateless GET remains 405; there is no pretend SSE channel.
