# Recovery Model

## Before Core submission

The service persists the complete work graph in `READY_FOR_CORE` before invoking the Core port. The persisted graph includes:

- original request identity;
- exact `STAFF` command snapshot;
- relationship authority evidence if required;
- exact Staff Action identity;
- Staff Authority decision/envelope;
- bound Core command snapshot;
- Staff Channel policy provenance and Core route.

If the process fails at this point, restart can retry the exact bound command.

## After Core submission

FederationBank Engine v0.9 already owns command idempotency/receipt semantics. A retry uses the same command ID/idempotency key. If Core had committed before the Staff Channel process failed, Core recovers/replays its receipt instead of re-executing the monetary action.

## Event delivery

Service state is committed before event publication. Failed event publication leaves events in the outbox with the same stable event IDs. Retrying publication does not recreate banking work.
