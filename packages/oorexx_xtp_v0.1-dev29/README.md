# ooRexx XTP v0.1-dev29

**Architecture:** Tom Dyer. **Coding:** ChatGPT and Codex (dev1 to dev25); Claude (Opus 5.5) for dev26 to dev29. **This section written by:** Claude (Opus 5.5), 25 October 2026.

dev29 adds the XTP 3.4 status handshake (SYNC/ECHO) to unicast streams, and DIAG replies for refused contexts. It also fixes a silent data-loss bug in dev28. A dev28 stream sender believed a delayed close-ACK left over from an earlier transfer that used the same KEY. It reported success, and the new data was never delivered.

**SYNC/ECHO.** Both fields already exist in the profile: ECHO at control offset +16 and SYNC at +20.

- The sender issues status requests: a CNTL from the sending end, with SREQ set and a SYNC value. It sends one after its first burst, one after first sending the final segment, and one on every timeout.
- SYNC values start at a random base for each context.
- The receiver echoes the latest SYNC in every CNTL for that stream.
- Once a peer has echoed, the sender believes only CNTLs whose ECHO belongs to this context. A stale or duplicated CNTL from another context is ignored, and counted in `XTP_STALE_CONTROL_IGNORED` on stderr.
- The reply to SYNC *k* reflects every packet sent before *k*. Any segment sent before *k* and still not covered is therefore lost, and is resent immediately. Tail loss no longer needs a timeout.
- Waits are 2 × the measured round trip, with a 10 ms floor, doubling on each consecutive timeout up to 8 × `timeout_ms`.
- A peer that never echoes (dev28 or earlier) keeps the dev28 rules and the fixed `timeout_ms`.
- A CNTL with ECHO = 0 is byte-identical to dev28.

**DIAG.** Packet type 8, the XTP 4.0 code; no verified 3.4 code was available.

- The data segment is CODE, VALUE, then an ASCII reason.
- A listener sends DIAG (code 1, CONTEXT_REFUSED) when:
  - a named service is not admitted (value 1, SERVICE_NOT_ADMITTED);
  - a stream exceeds its bound (value 2, OVERSIZE);
  - a payload cannot be decoded (value 3, MALFORMED).
- Every unicast sender, single-FIRST and stream, fails at once with `XTP context refused by peer: <reason>`. A DIAG must pass the same source and return-bit checks as an ACK, so a DIAG from anywhere else is ignored.
- Older senders drop the unknown packet type and time out as before.

**Tests:**

| Test | Checks | dev28 | dev29 |
| --- | --- | --- | --- |
| Y1 | A recorded close from an earlier context with the same KEY is injected while a new transfer starts | Reports success; new data never delivered | Delivered |
| Y2 | 100 KB at 20%/14% loss, `timeout_ms` = 2000 | 2,010 ms | 7 ms |
| Y3 | A status request is answered with ECHO = SYNC | n/a | PASS |
| D1 | Refused service | 6.1 s single / 6.5 s stream, "retries exhausted" | 1 ms, reason SERVICE_NOT_ADMITTED |
| D2 | A forged DIAG from a non-destination port is ignored | n/a | PASS |

Run them with `make test-sync-diag`.

`tests/test_operational_socket_rexx.sh` is a new ooRexx test of the dev26 zero-throttle refusal in `XtpOperationalSocket`. `run_tests.sh` runs it when `REXX_BIN` is set. **It has not been run yet:** the build machine has no ooRexx interpreter.

`make test-interop` now runs against dev28, and its labels name both versions.

# ooRexx XTP v0.1-dev28

**Architecture:** Tom Dyer. **Coding:** ChatGPT and Codex (dev1 to dev25); Claude (Opus 5.5) for dev26 to dev28. **This section written by:** Claude (Opus 5.5), 25 October 2026.

dev28 adds selective retransmission to unicast streams. In dev27 a single lost packet made the sender go back and resend everything after it. Under 20% forward and 14% reverse loss, a 200-segment transfer resent 8,867 packets. dev28 resends 49 for the same loss.

**Wire format.** It uses the XTP 3.4 field reserved for this purpose:

- The CNTL control segment's last word, at offset +36, is NSPAN. libxtp has always written it as 0.
- dev28 receivers follow the 40-byte control segment with NSPAN pairs `[start, end)` of bytes received beyond RSEQ, at most 64. The existing DCHECK covers them.
- A CNTL with NSPAN = 0 is byte-identical to dev27.
- dev26 and dev27 parsers ignore the spans.
- An overlong NSPAN, or a span whose end is not after its start, is refused as malformed.

**Receiver:**

- Keeps out-of-order segments inside its advertised window and reports them as SPANs.
- Fixes two dev27 bugs:
  - A retransmitted FIRST (its CNTL was lost) used to reset the stream and discard everything received. It no longer does.
  - A FIRST resent after the stream completed used to start a new stream. It now just re-sends the close.

**Sender (unicast streams only; multicast is unchanged):**

- A hole below the highest SPAN is resent once 2 × SRTT has passed since it was last sent.
- A receiver that never reports SPANs (dev27) gets go-back-N after three duplicate CNTLs.
- A full timeout with no CNTL resends everything unacknowledged inside ALLOC.
- `retries` bounds consecutive timeouts without progress.

**Tests:**

| Test | Checks |
| --- | --- |
| `make test-segmentation`, S3 | 200 segments through 20%/14% loss; retransmissions must stay within 2 × forward losses + reverse losses + 20. dev28: 49 for 49 forward and 28 reverse drops. dev27 fails it (8,680). |
| S6 | An identical stream resent with the same KEY is acknowledged, not delivered twice. dev27 fails it. |
| S7 | A retransmitted FIRST mid-stream keeps progress. dev27 fails it. |
| S8 | An out-of-order segment is reported as a SPAN, and filling the gap completes the stream. |
| S9 | NSPAN round-trips; an NSPAN = 0 CNTL has the dev27 layout; malformed NSPAN is refused. |
| `make test-interop` I1 | dev28 sender to dev27 receiver, separate processes, 150 KB through a 20%/14% lossy relay. Delivered; go-back-N fallback, 5,238 resends. |
| I2 | dev27 sender to dev28 receiver. Delivered; 191 resends, because the receiver keeps out-of-order data. |
| I3 | dev28 to dev28. Delivered; 37 resends. |

`make test-interop` needs `PEER_ROOT` set to a dev27 source tree. It builds the peer in a scratch copy and never writes into the repository.

# ooRexx XTP v0.1-dev27

**Architecture:** Tom Dyer. **Coding:** ChatGPT and Codex (dev1 to dev25); Claude (Opus 5.5) for dev26 and dev27. **This section written by:** Claude (Opus 5.5), 24 October 2026.

dev27 adds unicast segmentation. Before dev27, `send_message` put a whole message into one FIRST. On L2, which has no IP fragmentation, anything larger than about 1,456 bytes could not be sent. That covers most RTO2 traffic MU↔MI and every 16 KiB XMP1 multipath chunk.

**How it works:**

- A message, plus its named-service segment, that fits `SendOptions::segment_bytes` is still one FIRST with EOM, byte-identical to dev26. dev26 and dev27 processes interoperate both ways for such messages over UDP and L2 (validated with `xtp-listen` and `xtp-connect`).
- A larger message becomes a stream: a FIRST without EOM, then DATA packets carrying byte SEQ, with MULTI clear and SREQ on every packet. **The receiver must be dev27 or later.** A dev26 listener drops the first segment as an undecodable envelope and never ACKs it, so the sender fails closed.
- The default `segment_bytes = 0` means automatic:
  - L2: interface MTU − 40.
  - raw36 and UDP: one maximal IP datagram, so every message that worked before keeps the single-FIRST path.
  - On lossy WAN routes (for example XTP-over-UDP to Google), set it explicitly, for example to 1200, rather than relying on IP fragmentation.
- The sender reuses the existing go-back-N engine with one receiver, and honours receiver ALLOC, RATE/BURST and the operational `capacityRate`. Retries bound consecutive rounds without progress, so a transfer that keeps advancing is not cut off. Once a round's first ACK arrives, the sender waits only a short grace for the rest. Multicast behaviour is unchanged.
- The listener reassembles per (peer host, KEY):
  - Service admission happens at FIRST.
  - Decoding happens before the final close-ACK (the dev26 E6 rule).
  - ALLOC is bounded by half the socket's real receive buffer, so a full-window burst cannot overflow it.
  - Up to 256 streams can be open at once.
  - A completed stream re-ACKs a lost final close.
  - An identical stream sent again with the same KEY is flagged as a replay.

`make test-segmentation`:

| Test | Checks |
| --- | --- |
| S1 | UDP, 300 KB in 1024-byte segments, named service: byte-exact |
| S2 | L2 (lo), 100 KB in 1456-byte Ethernet-sized segments: byte-exact |
| S3 | UDP through a relay dropping 20% forward and 14% reverse: byte-exact after recovery |
| S4 | A stream for a service the listener doesn't admit is refused; nothing is delivered |
| S5 | A small message is still exactly one FIRST with EOM on the wire |
| S6 | An identical stream resent with the same KEY is delivered once, then flagged as a replay |

**Known limitation:** there is no selective retransmission (XTP ECNTL/SPANS). Under S3's deliberate loss, a 200-segment stream retransmitted 8,867 packets, about 44 times the data. The transfer is correct, but heavy loss is expensive. This is the next item in `docs/XTP_SPEC_GAPS_DEV27.md`.

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
