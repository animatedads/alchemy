# Component Projection design — dev6

## Principle

Component Projection is a capability, never a necessity.

A component owns its state and mutations. Component Projection supplies only a hierarchical discovery/projection contract. FUSE, SQL, object browsing and other front ends are renderers over that contract.

```
 component authority
      |
 typed observations + explicit mutations
      |
 component.projection/0.1
      |
 +----+--------------------+
 |                         |
 FUSE renderer             object/relation renderer
 files / cat / echo        assorted SQL / IBM i objects
```

No renderer becomes authority and no renderer is required for component operation.

## REPORT and CONTROL

`REPORT` is readable and never writable.

`CONTROL` is explicit, bounded and write-only by default. A control can opt into readability only where a meaningful current value exists.

FUSE write semantics are command-like: multiple kernel write chunks are accumulated and dispatched once on release. Namespace create/delete/rename is denied because registration owns the namespace.

## Adapter rule

An adapter may discover and register component-owned objects. It must not duplicate authoritative state or invent a second mutation path.

- QueueRexx adapter: store/status/health delegation only; no mutation endpoints.
- Queue Fabric adapter: reads through the manager/queue objects; `inject` delegates to `ObjectQueueManager~put()` and therefore inherits Queue Fabric authority checks.

Adapter refresh is namespace lifecycle only. It may add/remove projection endpoints when jobs, queues, peers or accounts appear/disappear. It may not create/delete the underlying resource.

## Identity and pathname separation

The filesystem path is presentation. Component identity remains the component's original object identity.

Presentation escaping currently encodes `%` and `/`. Internal adapter keys are typed Arrays, e.g.:

```
["queue", originalQueueName, "depth"]
["job", originalQid, "state"]
```

This avoids delimiter parsing and prevents Unix pathname syntax from contaminating the canonical object model. The same typed keys are suitable for non-Unix renderers.

## Future adapters

The same rule applies to planned adapters:

- IMAP: session/capability/mailbox/storage projection objects; controls only through existing IMAP operations.
- Storage Fabric self-reporting: resident provider/object/transfer facts; avoid recursive resolution through its own mounted projection.
- QueueBash: adapter over queue/class/worker facts and approved control seams; QueueBash itself does not acquire an ooRexx or FUSE dependency.

## Adapter rule added in dev4

Observation adapters MUST NOT create work merely because an endpoint is read. IMAP reports inspect resident session/selected-mailbox state and do not issue protocol commands. Storage Fabric self-observation inspects caller-supplied authoritative objects and does not re-enter the FUSE projection. This is the anti-recursion boundary for self-reporting.


## Inspector self-state versus inspected object tree

There are two distinct projections and they must not be conflated:

1. **Inspector live state** — configured rules, findings/warnings, trigger/security/trace event state, and resident Inspector counters. Component Projection dev5 owns only this adapter.
2. **Inspector-produced process/object tree** — a crawl/snapshot of the inspected application and its object graph. A separate Storage Fabric publisher may expose that output.

The live-state adapter is passive. Its read path is `InspectorClouseau~asDirectory` only. Namespace `refresh` may discover that a resident array gained or lost entries, but it does not trigger new inspection work.

## NoSQL rendering

NoSQLServer is another optional renderer alongside FUSE/object/SQL views. It receives a point-in-time snapshot of registry metadata and readable values. It does not become a dependency of core `component.projection/0.1`, and it cannot turn a CONTROL endpoint into a database mutation route.

A deployment may therefore have any combination of:

```
component -> Component Projection -> FUSE
component -> Component Projection -> NoSQLServer
component -> Component Projection -> assorted SQL / object view
```

without requiring any of the other branches.


## Dynamic Inspector rule schema

Inspector rules are authoritative resident `Directory` records. The adapter enumerates each record through its supplier and projects every field without translating the rule into a second schema. Convenience paths such as `kind`, `pattern`, and `enabled` therefore coexist with richer rule-specific fields when present.

This is namespace/reporting adaptation only: rule evaluation, mutation, installation and trigger behaviour remain owned by Inspector Clouseau.

## Renderer formatting boundary

FUSE text is file-oriented and conventionally line-terminated. NoSQL `value_text` is relation-oriented and is not. The NoSQL renderer strips only the final line terminator produced by the generic text renderer; it does not change the underlying object or embedded newlines. Renderer presentation must not leak back into canonical component values.
