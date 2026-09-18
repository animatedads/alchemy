# Component Projection capability 0.1-dev6

Optional, projection-neutral reporting/control for ooRexx components.

The canonical contract is **typed objects in a hierarchical namespace**. A component may opt in by registering `REPORT` endpoints and explicit `CONTROL` endpoints. Nothing requires FUSE, Linux, SQL, QueueRexx, QueueBash, Queue Fabric, IMAP or Storage Fabric.

## Renderers

- **Storage Fabric FUSE**: optional `/proc`-like reports and `/dev`-like controls. Reads snapshot once per open; writes are bounded, buffered and committed once on release.
- **Object / relation / assorted SQL**: typed values remain typed. Metadata enumeration does not invoke live reads unless a snapshot is explicitly requested.

The registry is namespace/discovery plumbing, not authority. Reads resolve to component-owned objects. Writes delegate to component-owned mutation seams.

## dev3: optional component adapters

### QueueRexx

`src/adapters/ComponentProjectionQueueRexx.cls`

`QueueRexxComponentProjectionAdapter` discovers current QueueRexx records and projects:

```
/queuerexx/jobs/count
/queuerexx/health                         (when a health scanner is supplied)
/queuerexx/jobs/<qid>/state
/queuerexx/jobs/<qid>/path
/queuerexx/jobs/<qid>/name
/queuerexx/jobs/<qid>/class
/queuerexx/jobs/<qid>/priority
/queuerexx/jobs/<qid>/command
/queuerexx/jobs/<qid>/status             (when a status projector is supplied)
```

The adapter is observation-only. It uses the existing QueueRexx store/status/health objects and contains no QueueRexx mutation path.

### Queue Fabric

`src/adapters/ComponentProjectionQueueFabric.cls`

`QueueFabricComponentProjectionAdapter` projects manager and queue facts plus an explicit write-only injector:

```
/queuefabric/queue_count
/queuefabric/active_uow_count
/queuefabric/transfer_receipt_count
/queuefabric/queues/<name>/state
/queuefabric/queues/<name>/lifecycle
/queuefabric/queues/<name>/security_domain
/queuefabric/queues/<name>/max_depth
/queuefabric/queues/<name>/owner
/queuefabric/queues/<name>/created_at
/queuefabric/queues/<name>/depth
/queuefabric/queues/<name>/backout_threshold
/queuefabric/queues/<name>/backout_queue
/queuefabric/queues/<name>/inject
```

`inject` calls `ObjectQueueManager~put()` with the configured principal. Queue Fabric access policy remains authoritative: projection cannot bypass PUT authority.

Names are escaped only for namespace presentation (`%` -> `%25`, `/` -> `%2F`). Adapter dispatch uses typed Array keys containing the original QueueRexx QID or Queue Fabric queue name, so filesystem syntax never becomes canonical component identity.

## Lifecycle

Adapters expose `install`, `refresh`, and `uninstall`. `refresh` discovers new jobs/queues and unregisters vanished ones. Registration lifecycle is separate from component lifecycle; removing a projection never deletes or mutates the underlying QueueRexx record or Queue Fabric queue.

## Compatibility

Core API remains `component.projection/0.1`.

Adapter APIs:

- `component.projection.queuerexx/0.1`
- `component.projection.queue-fabric/0.1`

The adapters are independently loadable. Systems not using them are unchanged.

## dev4 additions

- `ComponentProjectionImap.cls`: observation-only adapter over an existing IMAP session. It exposes session state and, while one is selected, the authoritative selected-mailbox state. It deliberately issues no IMAP commands.
- `ComponentProjectionStorageFabric.cls`: Storage Fabric self-observation over supplied catalogue/workspace objects. It exposes catalogue and workspace/allocation facts without creating a recursive dependency or a control path.

Both adapters are independently loadable and optional. A component remains fully functional when Component Projection is absent.


## dev5 additions

### Inspector Clouseau live-state adapter

`src/adapters/ComponentProjectionInspectorClouseau.cls` exposes **Inspector Clouseau itself**, not the inspected process/object tree. It reads only `InspectorClouseau~asDirectory` and never calls `snapshot()`, `refreshObservation()`, object-graph walking, snapshot writers, or trace-request scanning.

Representative paths:

```
/inspector/rules/count
/inspector/rules/<n>/kind
/inspector/rules/<n>/pattern
/inspector/rules/<n>/value
/inspector/rules/<n>/enabled
/inspector/rules/<n>/record
/inspector/findings/count
/inspector/warnings/count
/inspector/triggers/count
/inspector/security_events/count
/inspector/trace_reports/count
/inspector/trace_requests/count
/inspector/scheduled_snapshots/count
/inspector/state/roots
/inspector/state/packages
/inspector/state/objects
/inspector/state/edges
/inspector/state/queues
/inspector/state/classes
/inspector/state/methods
```

This is intentionally separate from any Storage Fabric module that publishes Inspector-produced snapshots or an object/process tree.

### NoSQL renderer

`src/ComponentProjectionNoSQL.cls` is an optional renderer over the same registry. It builds read-only `ObjectDatabaseEngine` snapshot tables:

```
component_endpoints
component_values
```

`component_endpoints` is metadata-only. `component_values` invokes readable endpoints when the snapshot is built and records path/component/kind/media type/value class plus rendered value text. Control endpoints are never invoked or made writable through NoSQL. `snapshotInto()` follows the existing `registerSnapshot()` federation shape.

The canonical value remains the component-owned object in Component Projection; NoSQL text is renderer output, not authority.


## dev6 exact API grounding

The Inspector and NoSQL adapters are now qualified against the current APIs from the refreshed ooRexx API bundle:

- Alchemy Objects v0.8 Inspector Clouseau (`InspectorClouseau~asDirectory`)
- NoSQLServer v0.79 (`ObjectDatabaseEngine`, `ObjectTableMapping`, `registerSnapshot`)

Inspector rule records are treated as dynamic `Directory` objects. Every resident field is projected under `/inspector/rules/<n>/<field>`; the adapter does not assume a fixed rule schema. This preserves signal/method/trace-specific fields such as `class_pattern`, `method_pattern`, `signal_pattern`, condition fields, source/stack bounds, and report prefixes.

The NoSQL renderer now uses real frozen `registerSnapshot()` tables. Its `value_text` renderer removes the final Unix/FUSE line terminator so SQL text values are values rather than file records; embedded newlines remain intact.

The supplied Provenance Ledger v0.1-dev5 is compatible with the qualification environment but is not made a dependency of Component Projection or the NoSQL renderer.
