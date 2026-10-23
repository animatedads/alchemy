# ooRexx XTP v0.1-dev25

Dev23 consumes Operational Degradation Planner dev2 capacity scopes. XTP enforces the per-context percentage cap (combined with THROTTLE by taking the lower percentage). `MAX_PARALLEL_CONTEXTS` and `AGGREGATE_CAP_PERCENT` remain orchestration/admission controls for Storage Fabric and other planners; XTP does not counterfeit cross-context global accounting.

# ooRexx XTP v0.1-dev22

Dev22 adds the named-service access layer to the existing XTP transport.

The application-facing target is now capable of being a canonical service name
(`ssh.management`, `radar.primary`, `fire-control.primary`, etc.) rather than a
network address. The service descriptor carries no IP address. It resolves to a
logical XTP route peer; only the XTP route table contains carrier addresses.

Named services are carried in a private XTP FIRST address-format segment
(`0xA11C`). Once the context is established, ordinary KEY/ROUTE processing is
unchanged. Listener admission can fail closed on the named service before an
acknowledgement is emitted.

The ooRexx `XtpNamedServiceManager` binds Service Descriptor Registry entries to
XTP and derives the operational class from the local registration rather than
trusting a caller-supplied class. In constrained/emergency states it can expose
only services admitted by the transport-neutral Operational Degradation
Planner.

See `docs/NAMED_SERVICES.md`.

## dev25 named-service binding repair
- Registers `xtpNativeSendService`, `xtpNativeListenerOpenServices`, and `xtpNativeListenerLastService` in the ooRexx native routine table.
- Fixes `-Werror=misleading-indentation` in the allowed-service parser.
- `XtpNamedServiceManager~listener` now exposes `planner` and `operatingState`, so degraded/emergency admission uses the manager's actual policy state.
- Native ooRexx link explicitly includes the operational-planner archive.
- `test-service` executes shell tests through `bash`, so ZIP extraction permission loss is not an acceptance blocker.

## dev25 operational capacity enforcement

`SendOptions.max_rate_bytes_per_sec` is an explicit capacity-ticket rate. Unicast L2, native raw36 and L4 UDP pace each physical transmission attempt against that rate. The ooRexx named-service socket exposes `capacityRate(bytesPerSec)` and preserves service name plus SORT/DEADLINE priority when using the rate-limited native send routine. A zero rate means no explicit sender-side capacity ticket.

This is deliberately separate from receiver-advertised XTP RATE/BURST: the operational capacity ticket is a local policy ceiling; the receiver's RATE/BURST remains XTP flow-control information. Where both exist, an ongoing stream implementation must obey the stricter limit.

### Automatic context keys

A zero `SendOptions.key` now requests a process-unique 31-bit XTP context key. This is the default. Explicit non-zero keys remain available for tests/protocol control. This prevents repeated named-service sends from being mistaken for replay solely because a convenience API reused a fixed default key.
