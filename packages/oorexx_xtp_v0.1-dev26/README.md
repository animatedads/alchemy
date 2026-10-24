# ooRexx XTP v0.1-dev26

**Architecture:** Tom Dyer. **Coding:** ChatGPT and Codex (dev1 to dev25); Claude (Opus 5.5) for the dev26 hardening. **This section written by:** Claude (Opus 5.5), 24 October 2026.

dev26 is a hardening candidate on dev25. It does not change the wire format or any valid exchange, and every dev25 regression test still passes. It closes the transport findings from the 23 October independent review that need neither keys nor a gateway.

| Finding | dev25 behaviour | dev26 behaviour | Test |
| --- | --- | --- | --- |
| R-07 | Sender accepted a close-ACK from any source | Close-ACK accepted only from the route destination: UDP address and port; raw36 address; L2 destination MAC, addressed to our MAC | N1, N1-L2 |
| Spec | Sender never checked the XTP return bit on a close-ACK's KEY | A close-ACK whose KEY lacks the return bit is ignored | N1-RTN |
| R-08 | Unicast L2 listener ACKed and delivered frames addressed to a foreign MAC | Ignored unless addressed to the listener's own MAC | N2 |
| R-09 | THROTTLE at 0% sent with zero delay, although the planner refuses the ticket | `operational_path_permitted` is false; `operational_delay_for_bytes` is maximal; ooRexx `XtpOperationalSocket~send` returns -7 | N8 |
| E6 | A malformed FIRST threw out of `Listener::receive()` and killed the caller's loop | Dropped unacknowledged with `XTP_DROP_MALFORMED` on stderr; the listener keeps serving | E6 |
| E6 | The envelope was decoded after the close-ACK, so an undecodable FIRST was reported delivered | Decoded before the ACK; on failure no ACK is sent | E6 |
| E7 | Replay keyed on KEY alone, in an unbounded set; a colliding 31-bit KEY (for example XMP1 chunks of two transfers) was ACKed and silently dropped | Keyed on (peer host, KEY, FIRST payload digest), in a window bounded by `ListenOptions::replay_window_entries` (default 65536) | E7 |

Run the adversarial suite with `make test-negative`. To prove each test fails on dev25:

```
SRC_ROOT=/path/to/oorexx_xtp_v0.1-dev25 DEV26=0 bash tests/run_negative.sh
```

**Replay scope.** A replay is the same peer host, the same KEY and the same FIRST bytes. The peer host is the source MAC on L2 and the source IPv4 address on raw36 and UDP. The UDP port is deliberately excluded, so a sender process that restarts and retries the same KEY and payload is still suppressed; dev25 test 5 depends on this. Two hosts that choose the same KEY, and two different contexts whose KEYs collide on one host, are no longer falsely suppressed. Once the window is full, the oldest contexts are forgotten and could be delivered again.

**What dev26 does not do** (the protocol-level gaps are listed in `docs/XTP_SPEC_GAPS_DEV26.md`):

- Source binding is not authentication. An attacker able to forge the destination's own address can still forge an ACK. Authenticated FIRST and ACK are the gateway's job (independent review section 4, steps 2 and 6).
- The multicast listener's replay scope is unchanged.
- `send_message` still does not consult the operational plan itself. Callers must check `operational_path_permitted` first.
- `capacityRate(0)` still means "no sender-side ticket", which is unlimited. A caller that passes a refused ticket's 0 bytes per second therefore sends unthrottled. Changing this needs an architect decision, because Storage Fabric and Memory Fabric rely on the current meaning.
- The ooRexx change (7 lines in `rexx/XtpSocketProvider.cls`) has NOT been run, because no ooRexx interpreter was available in the build environment.

**Metadata.** CAPABILITIES.json, DEPENDENCIES.json and integration.json now all say 0.1-dev26; dev25's files said dev23. The `named_service` block that dev25 dropped is restored. The planner dependency is dev5, matching the Makefile. `test_capability_contract.sh` now fails if these drift again. integration.json publishes the source tree (`publish.tree`) rather than an artifact only.

# ooRexx XTP v0.1-dev25

dev23 consumes Operational Degradation Planner capacity scopes; dev26 builds against planner dev5. XTP enforces the per-context percentage cap (combined with THROTTLE by taking the lower percentage). `MAX_PARALLEL_CONTEXTS` and `AGGREGATE_CAP_PERCENT` remain orchestration/admission controls for Storage Fabric and other planners; XTP does not counterfeit cross-context global accounting.

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
