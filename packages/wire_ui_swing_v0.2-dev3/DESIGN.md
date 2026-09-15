# Wire UI Journey -> Swing design contract

## Authority

Swing owns presentation instances, local focus/selection/edit state before an action, and renderer-local error containment. It does not own journey transitions, action permission, business state, experiment assignment, authentication, or release selection.

## Failure scopes

- `PROPERTY`: retain the component and report a failed slot application.
- `COMPONENT`: use a controlled placeholder for an unsupported primitive or rejected exact definition.
- `SUBTREE`: abort the proposed structural render; retain the previously committed tree.
- `PATCH`: reject invalid revisions/operations; request resynchronisation where appropriate.
- `WINDOW`: reserved for a future top-level window recovery shell.
- `PROCESS`: never used for ordinary Wire/application/rendering faults.

## Transaction rule

A patch is split into two phases:

1. Preflight against the semantic mirror: revision, operation shape, instance existence, parent existence, exact definition availability.
2. EDT commit only after preflight succeeds.

This prevents the classic Swing failure where operation N mutates widgets and operation N+1 discovers that the patch cannot actually be applied.

## Action rule

Swing listeners perform local value capture only and enqueue a `UI_ACTION`. No listener calls application logic, ooRexx, Queue Fabric, JMS, network code, or waits for a server response.

The runtime stamps `viewRef` and `revision` **when the Swing event is queued**, not when a transport thread later drains it. An incoming patch may advance the renderer while the action is waiting in the queue; that must never rewrite the historical revision against which the user acted.

## Structural relayout rule

A successful `CREATE_INSTANCE` may change composition order, but it must re-layout existing `JComponent` instances rather than reconstruct siblings. Renderer-local state such as unsent `JTextField` edits therefore survives a structural insertion unless the semantic protocol explicitly replaces that instance.

## Presentation rule

Swing may interpret renderer-neutral presentation hints such as `styleRole`, native focus state and active look-and-feel, but presentation must not become semantic authority. A presentation role can change font/border/margin/cell text; it cannot change actions, permissions, business values, journey transitions or server identities.

Collection renderers may derive a human-facing cell label from display fields, but an actionable collection returns only the browser-parity action detail (`index` plus a recognised server identity such as `offerId`). Display-only fields are not echoed back as authority payload.

## Standalone demo authority

The executable demonstration contains a deliberately separate `WireSwingStandaloneDemo`. It simulates the server side of a journey for packaging and human inspection only:

```text
Swing widget -> UI_ACTION -> demo authority -> authoritative UI_VIEW_SNAPSHOT -> Swing
```

`WireSwingRuntime` does not switch SEARCH/SUMMARY/TRANSACTION itself. Removing the demo authority leaves a normal passive renderer waiting for transport messages.
