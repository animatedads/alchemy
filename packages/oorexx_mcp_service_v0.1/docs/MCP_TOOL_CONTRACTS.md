# MCP tool contracts

Protocol revision: `2026-07-28`.

## `sphere.check`

Input: `sphereId` required, `componentId` optional. The Gopher adapter runs `sphere resolve` against configured API roll-up and local override directory and returns the complete structured Gopher result including selected source and archive SHA-256. Component validation is applied when `componentId` is supplied.

## `project.components.list`

Input: optional `componentId`. Returns current component catalogue rows plus active ownership, total request count and caller-visible unread count.

## `project.request.create`

Input: `componentId`, `body`; optional `recipientId`, `subject`, `requestType`. Sender is always the authenticated HTTPS principal. Omitted recipient resolves to current owner or component mailbox.

## `project.ownership.claim`

Input: `componentId`; optional `claimRequestId`. Owner is always the authenticated HTTPS principal. Existing ownership by another principal fails with `OWNERSHIP_CONFLICT` and includes the current ownership object.

## `project.requests.list`

Input: optional `componentId`, `unreadOnly`. Visibility is sender, explicit recipient, wildcard recipient, or active owner of a component-mailbox request.

## `project.request.mark_read`

Input: `requestId`. Creates an idempotent per-reader receipt. It never edits the request.

## `project.request.reply`

Input: `requestId`, `body`; optional `recipientId`, `subject`, `requestType`. Creates a new request. Default recipient is the parent sender. `parentRequestId` is the supplied request, `rootRequestId` is inherited.

## MCP error distinction

Malformed MCP transport/protocol input is returned as a JSON-RPC error. A valid `tools/call` whose project operation is rejected returns a normal MCP tool result with `isError: true` and structured `{ok, code, detail, value}`. This lets clients distinguish protocol failure from application-policy failure.
