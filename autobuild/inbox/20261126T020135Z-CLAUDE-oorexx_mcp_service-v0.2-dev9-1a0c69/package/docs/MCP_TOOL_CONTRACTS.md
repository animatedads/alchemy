# MCP tool contracts

Protocol revision: `2026-07-28`.

## `sphere.check`

Input: `sphereId` required, `componentId` optional. The Gopher adapter runs `sphere resolve` against configured API roll-up and local override directory and returns the complete structured Gopher result including selected source and archive SHA-256. Component validation is applied when `componentId` is supplied. If that component is a first-class sphere component, its recorded `sphereId` must match or `SPHERE_COMPONENT_MISMATCH` is returned.

## `project.components.list`

Input: optional `componentId` and optional `componentKind` (`runtime` or `sphere`). Returns composite project-catalogue rows plus active ownership, total request count and caller-visible unread count. Sphere components use canonical IDs `sphere:<sphereId>`; unambiguous convenience aliases are accepted.

## `project.request.create`

Input: `componentId`, `body`; optional `recipientId`, `subject`, `requestType`. Sender is always the authenticated HTTPS principal. Omitted recipient resolves to current owner or component mailbox.

## `project.ownership.claim`

Input: `componentId`; optional `claimRequestId`. Owner is always the authenticated HTTPS principal. Existing ownership by another principal fails with `OWNERSHIP_CONFLICT` and includes the current ownership object.

## `project.ownership.release`

Input: `componentId`; optional `releaseRequestId`, `reason`. The caller must be the authenticated active owner. A successful release appends immutable `OWNERSHIP_RELEASED` evidence and removes the component from the active-ownership projection. Another principal receives `OWNERSHIP_RELEASE_FORBIDDEN`; an already-unowned component returns idempotent success `ALREADY_UNOWNED`.

## `project.requests.list`

Input: optional `componentId`, `unreadOnly`, `limit` (integer 1–100, default 10), `maxBodyBytes` (integer 0–8000, default 1500), `newestFirst` (boolean, default false), `afterId` (request ID). Visibility is sender, explicit recipient, wildcard recipient, or active owner of a component-mailbox request.

Output schema `oorexx.mcp.request.list/2`: `requests`, `count` (returned), `total` (all matches), `hasMore`, `nextAfterId` (pass as `afterId` for the next page; empty when nothing remains), `limit`, `maxBodyBytes`, `order`. Each request carries `bodyBytes` and `bodyTruncated`; its body is cut to `maxBodyBytes` on a UTF-8 boundary and a subject over 300 bytes is cut and ends in `...`. Errors: `INVALID_ARGUMENT` for out-of-range or non-whole numbers, `REQUEST_NOT_FOUND` for an unknown `afterId`. (v0.2-dev9; before that the list was unbounded.)

## `project.request.get`

Input: `requestId`; optional `offset` (1-based byte, 1–body length, default 1), `length` (1–16000, default 8000). Visibility as for the list. Returns the request with its body replaced by one page plus `bodyBytes`, `bodyOffset`, `bodyLength`, `bodyHasMore`, `nextOffset` (0 when no more). Cuts fall on UTF-8 boundaries; an offset inside a character moves back to the lead byte; a page always advances by at least one whole character. Does not create a read receipt. Errors: `REQUEST_NOT_FOUND`, `REQUEST_NOT_VISIBLE`, `INVALID_ARGUMENT`, `AUTHENTICATED_PRINCIPAL_REQUIRED`. (v0.2-dev9)

## `project.request.mark_read`

Input: `requestId`. Creates an idempotent per-reader receipt. It never edits the request.

## `project.request.reply`

Input: `requestId`, `body`; optional `recipientId`, `subject`, `requestType`. Creates a new request. Default recipient is the parent sender. `parentRequestId` is the supplied request, `rootRequestId` is inherited.

## MCP error distinction

Malformed MCP transport/protocol input is returned as a JSON-RPC error. A valid `tools/call` whose project operation is rejected returns a normal MCP tool result with `isError: true` and structured `{ok, code, detail, value}`. This lets clients distinguish protocol failure from application-policy failure.

## Compatibility tool names (v0.2-dev5 onward)

The canonical API is unchanged.  An optional compatibility adapter advertises the
following one-to-one aliases: `sphere_check`, `project_components_list`,
`project_request_create`, `project_ownership_claim`, `project_ownership_release`,
`project_requests_list`, `project_request_get` (v0.2-dev9), `project_request_mark_read`, and `project_request_reply`.
Each alias dispatches to exactly the same uppercase semantic operation as its dotted
canonical name.  Compatibility names are a client-presentation concern, not a second
project API.

Advertised input schemas intentionally omit `$schema`; no tool requires JSON Schema
features beyond object/string/boolean/integer properties, required names, and
`additionalProperties: false`.
