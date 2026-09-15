# FlyLo v0.4 Engine Architecture

## Boundary rule

**Channels request. Airline backend authorities decide and execute.**

FlyLo v0.4 moves the reference booking path onto the same class of backend
machinery already proven in FederationBank: named Queue Fabric service
boundaries, separate authorities, bounded poison handling, retained restart
state and idempotent cross-service completion.

The browser remains a semantic Wire UI access point.  It does not own fares,
seat inventory, booking identity, operational state or replay decisions.

## Backend authorities

### Journey / Inventory Engine

`FlyLoJourneyAuthority` owns the reference schedule graph, itinerary
construction and seat-inventory commitment.

Search is presently bounded to direct or one-connection itineraries.  A
connection must be at least 45 minutes and no more than 360 minutes in the
explicit fixture schedule.

The issued offer contains exact leg identities and a per-passenger mandatory
fare.  Inventory commitment re-resolves every flight against the authority's
schedule and rejects tampered routes, currencies, passenger counts and fares.
It then commits all legs for one booking as one service-owned state change.

### Booking Engine

`FlyLoBookingAuthority` owns booking identity and confirmation state.  A
payment-authorisation identity is required before the booking engine will
prepare an inventory request.  Card data is not accepted.

Booking creation is a Queue Fabric saga:

```text
CHANNEL BOOKING_CREATE
  -> Booking Engine validates booking request
  -> FLYLO.INVENTORY.COMMIT
  -> Journey / Inventory Engine validates issued offer + seats
  -> retained inventory projection
  -> FLYLO.INVENTORY.OUTCOMES
  -> Booking Engine finalises booking
  -> retained booking projection
  -> CHANNEL booking result
```

The booking idempotency key and the derived inventory idempotency key are
independent.  Replaying a confirmed booking returns the existing booking and
cannot consume seats twice.

### Operations Engine

`FlyLoOperationsAuthority` owns the reference flight-status view.  The current
fixture supports `ON_TIME`, `DELAYED`, `CANCELLED`, `DIVERTED`, `DEPARTED` and
`ARRIVED` states.

## Queue authority

The channel principal may put requests onto Journey, Booking and Operations
command queues and consume their result queues.  It has no `PUT` authority on
`FLYLO.INVENTORY.COMMIT`.

The Booking worker may request an inventory commitment; only the Journey
worker consumes that command and mutates inventory.  Malformed work is
bounded by Queue Fabric backout policy and moved to `FLYLO.BACKEND.DLQ` after
two failed deliveries.

## Restart model

Inventory commits are retained on `FLYLO.INVENTORY.STATE`; confirmed bookings
are retained on `FLYLO.BOOKINGS.STATE`.

A newly constructed backend runtime rebuilds fresh Journey and Booking
authorities from those retained projections.  The restart regression proves
that a committed seat remains consumed, the booking remains discoverable and
a replay after restart does not consume a second seat.

Queue Fabric persistence is authority/replay evidence for this reference
slice.  It is not represented as a replacement for a production reservation
host database.

## Airport-to-airport fixture

The v0.4 explicit development schedule includes an invented network centred on
PIK.  For example:

```text
GLA --FL201--> PIK --FL101--> EWR
```

The route regression proves that the engine constructs this two-leg itinerary,
respects the bottleneck seat count and commits inventory on both legs when the
booking is confirmed.

These flight numbers, fares, times and capacities are test data only.

## Finance / Accounting authority

FlyLo v0.4.9 adds Accounting Core v0.3 without moving booking or payment truth into the ledger. The normal path is:

```text
Booking/ancillary operational fact
        |
        +-- payment AUTHORISED  -> no accounting event
        |
        +-- explicit CAPTURED evidence
                |
                v
        accounting.event/0.1
                | retained on FLYLO.ACCOUNTING.SOURCE.EVENTS
                v
        FlyLo AccountingEngine~transact()
                | effective-dated exact policy
                v
        immutable FlyLo AccountingBook journal
```

The finance principal may publish normalized capture evidence; the accounting worker may browse it. Ordinary channel/booking principals have no GL posting authority. Accounting Core checks source-event replay/conflict before current policy execution and binds every accepted draft to the event fingerprint, source authority, policy ref/identity and evidence refs.

Current FlyLo policy deliberately treats captured customer consideration as **card-processor receivable plus passenger-service contract liability**. Ticket and checked-bag revenue accounts exist but are not credited merely because a service was sold. Performance/revenue-recognition events are intentionally a later accounting-policy phase.

The retained event projection is the restart evidence for this reference slice. A fresh AccountingEngine rebuilds its independent book from those normalized events; it does not rebuild booking/inventory truth and cannot mutate those authorities.

## Production AS/400 boundary

FlyLo already has a working AS/400 operations boundary.  v0.4 deliberately
does **not** silently substitute the fixture engine for that production host
truth.

`FlyLoAS400OperationsAdapter` remains the production adapter boundary, while
`FlyLoQueueOperationsAdapter` is the v0.4 reference/backend-engine adapter used
by acceptance and by a composed server-side application path.

A later host-composition cut can place real AS/400 schedule/inventory/PNR calls
behind these Queue Fabric authorities without changing the browser or sales
process contract.  Until that composition is explicitly qualified,
`ENGINE_FIXTURE` remains visible on fixture results.

## Wire UI v0.16 passenger workspace authority

FlyLo v0.4.7 makes manage-booking the first transaction surface to consume Wire UI Server v0.16 workspace authority directly. Booking confirmation assigns immutable passenger identities (`PAX-001`, `PAX-002`, ...); restart recovery deterministically backfills those identities on older v0.4 projections that predate them.

`BOOKING.LOOKUP` registers `BOOKING.<ref>.PASSENGERS`. Browser selection and sorting are UI operations over server-owned workspace state. A passenger-scoped servicing action must carry the exact `WireUIWorkspaceCommandContext` minted by the server: workspace/query/scope/order/selection revisions plus selected semantic identities. Sorting preserves a semantic selection; changed scope invalidates it; stale or forged contexts are rejected before FlyLo semantic dispatch.

`BOOKING.ADD_CHECKED_BAG` is deliberately a new booking-engine operation rather than mutation of the historical sale. FlyLo authoritatively prices the requested service, obtains a separate payment-authorisation identity, appends ancillary-service evidence to the booking projection, and uses a servicing idempotency key derived from booking + selection revision + quantity. Exact replay therefore returns the existing service result rather than adding another bag.

The package-root `./flylo` development server now hosts a persistent ooRexx `FlyLoWireApplication` for these public semantic actions. The development authority is still visibly `ENGINE_FIXTURE`; this does not redefine the AS/400 production boundary.

## Non-goals in v0.4

- claiming the invented fixture timetable is a live FlyLo timetable;
- replacing AS/400 reservation truth with retained Queue Fabric projections;
- distributed transactions across Booking and Journey authorities;
- arbitrary multi-stop/network optimisation beyond one connection;
- payment-card handling inside FlyLo;
- moving pricing or inventory authority into Wire UI or JavaScript.


## v0.4.10 durable public runtime and v0.17 result authority

The package-root `./flylo` development runtime now supplies a durable root to Queue Fabric and an Accounting Core v0.7 `AccountingFileStore` under the same FlyLo data root. A booking/passenger projection therefore survives process restart; the public launcher no longer treats process memory as the lifetime of Manage Booking. Queue Fabric remains operational source evidence, while the AccountingFileStore is the durable native accounting book.

For passenger servicing, Wire UI Server v0.17 adds authoritative result state on top of v0.16 query/selection state. `BOOKING.<ref>.PASSENGERS` publishes a result revision tied to the exact query/scope/order revisions that produced the passenger/ancillary result. A command context must therefore match both semantic selection and the exact current result. After a bag changes the booking result, the previous context is stale even when it still selects the same `PAX-002`; FlyLo rejects it before semantic dispatch.
