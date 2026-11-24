# XTP specification gaps after dev33

**Architecture:** Tom Dyer. **Implementation reviewed:** libxtp dev25 to dev32 (ChatGPT and Codex to dev25; dev26 to dev32 by Claude). **Written by:** Claude (Opus 5.5), 24 October 2026; dev30 and dev31 changes 27 October; dev32 and dev33 changes 28 October 2026.

## Sources, and how far to trust them

The primary XTP 4.0 Specification (XTP Forum, 1995) and the XTP 3.4 Protocol Definition could not be fetched. The XTP 4.0 PDF lives at Sandia and Packeteer addresses that this environment can't reach. These sources were used instead:

| Ref | Source | What it gives |
| --- | --- | --- |
| S1 | NASA tutorial on XTP Revision 3.4 (Sanders and Weaver, 1990), NTRS 19910011483 | 3.4 concepts and field lists; bit-layout figures lost in the OCR |
| S2 | Wireshark XTP 4.0 dissector, `epan/dissectors/packet-xtp.c` | Exact 4.0 byte layouts; cites the XTP 4.0 PDF |
| S3 | UBC TR-95-17, XTP 4.0 API | 4.0 packet types, service types, timers |
| S4 | NetX XTP overview (University of Virginia) | General |
| S5 | DTIC ADA274941, an SCM model of XTP | Close variants |
| S6 | IANA registries | IP protocol 36 and EtherType 0x817D are both XTP |

**Tom: if you hold the XTP 4.0 specification or the 3.4 Protocol Definition, the bit positions marked "unverified" below can be settled against it.**

## Decision needed: 3.4 or 4.0

libxtp is an XTP 3.4 profile (`CAPABILITIES.json` "3.4 profile"; `docs/PROTOCOL_PROFILE.md`). XTP 4.0 is not wire-compatible with it. Per S2, 4.0 has:

- a 32-byte big-endian header with no trailer;
- a 64-bit KEY and SEQ;
- the Internet checksum (RFC 1071);
- its options in the CMD word.

The options are:

- **Stay on 3.4 and say so.** The 3.4 bit positions should be checked against the Definition.
- **Move the wire format to 4.0.** This is a new major profile, not a dev increment.

Every other gap below exists under either choice.

## Striping (decision D-01)

None of the sources defines striping, channel bonding, or bit or byte interleaving, and none has a negotiable option for them. The closest provisions are:

- ROUTE and XROUTE, which allow different routes per direction and per hop.
- S1's statement that packets of one context may arrive out of order because they took different routes.
- The XTP 4.0 FIRST traffic specification (TLEN, SERVICE, TFORMAT; MAXDATA, INRATE, INBURST, OUTRATE, OUTBURST), which is the only per-context negotiation vehicle.

To make striping "selectable" in the XTP manner, the selection would be carried in the FIRST traffic specification as a private value: a private TFORMAT or SERVICE value, 128 or above per S2's handling of unknown formats. It should be documented as an Alchemy extension, not as XTP.

Today's XMP1 multipath is not that. Each chunk is a separate XTP context, sent one at a time, so the paths are never in flight together. The bit-interleaved dual-channel mode in D-01 does not exist in code.

## Remaining gaps, in priority order

| # | Gap | Severity | Smallest change |
| --- | --- | --- | --- |
| 1 | Protected one-way messages have no handshake, so within the 30 s clock window a captured message can be delivered once at *another* listener holding the same service key (docs/SECURITY.md, "The limit of having no handshake"). Messages and streams are otherwise protected per service since dev33; sessions since dev32. Multipath (XMP1) chunks are not covered. | MEDIUM | Sessions for exactly-once across a pool; a receiver challenge for one-way messages would cost a round trip. |
| 2 | Single-FIRST unicast and multicast still wait a fixed `timeout_ms` with no backoff; RTT-timed waits (dev29) cover unicast streams only. | LOW | Send a SYNC with single FIRSTs too, or use the stream path for every unicast send. |
| 3 | On the message and stream paths, DSEQ is reported equal to RSEQ before the application has the data. Sessions (dev31) report it after delivery. | MEDIUM | Report DSEQ only after delivery. |
| 4 | The address segment is optional and detected by sniffing. Only third-party senders are at risk, since `send_message` always wraps the payload in an `XWF1` envelope. 0xA11C does not fit the 4.0 8-bit AFORMAT. | MEDIUM | Always emit a segment, using the NULL format when no service is named; under 4.0, use a private AFORMAT of 128 or above. |
| 5 | No traffic specification or service type in FIRST, and no MAXDATA/MTU negotiation. | MEDIUM | Emit at least MAXDATA and SERVICE; refuse an unsupported one with DIAG. |
| 6 | Messages and streams have only the abbreviated transaction close: no context state machine, no CTIMER keepalive and no reaping. Sessions (dev31) have all three. | MEDIUM | A context table with CTIMER. dev26's bounded replay window is an interim substitute for reaping. |
| 7 | Multicast CNTL replies are not slotted (no random delay or damping), so implosion risk grows with the receiver count. | LOW-MEDIUM | Random slot delay plus suppression when a peer's CNTL covers the same state. |
| 8 | BTAG, DADDR, RES, NOCHECK, DREQ and ETAG are never emitted, and unknown flags are not rejected. TTL is fixed at 64 (0.64 s). | LOW | One wire-constants table with a cited source for each bit; reject illegal flags. |
| 9 | Multicast is still go-back-N; selective repeat (dev28) covers unicast streams only. Multicast receivers would need per-receiver SPANs and the sender a union of holes. | MEDIUM | Reuse dev28's receiver store and SPAN encoding in the multicast listener. |
| 10 | SYNC/ECHO context binding protects streams only after the peer has echoed. Before the first echo arrives (the first round trip), and with peers that never echo (dev28 and earlier), an ECHO=0 CNTL is still believed. | MEDIUM | Authenticated CNTL (the gateway contract) closes this for every peer. |
| 11 | Several dev25-era test scripts use Python (run_tests.sh, test_multicast*.sh, test_multipath.sh, test_path_health.sh, test_requalification.sh, test_capability_contract.sh). No dev26 to dev29 code depends on it. | LOW | Port the checks to shell or ooRexx when those suites are next touched. |
| 12 | DIAG VALUEs 16 to 23 are reserved for the gateway (docs/DIAG_REGISTRY.md). Only 19 is sent yet, by a SessionListener that is full. A sender treats every DIAG as final, including ones whose cause may pass (QUOTA_EXCEEDED, NOT_READY). | LOW | When the gateway sends them, say in the sender error which VALUEs may be retried; retrying stays the caller's decision. |
| 13 | A session's sequence space is 32 bits per direction; `write()` refuses beyond 2^32 − 1 bytes, and the session must be reopened. | LOW | Sequence wrap with serial-number arithmetic (RFC 1982), or a 64-bit SEQ under a 4.0 profile. |
| 14 | The dev27 `Listener` receives into a 65,536-byte buffer. On `lo`, whose MTU is 64 KB, an L2 stream segment plus its Ethernet header is truncated and dropped. Real interfaces (1500 or 9000) are unaffected. Sessions use a larger buffer. | LOW | Same change in `Listener::receive`. |
| 15 | Each opened session uses its own socket and pump thread. That is fine for tens of sessions, but not for thousands from one process. | LOW | A shared initiator endpoint keyed by route. |

## Closed in dev33

- Gap 1 (messages and streams unprotected): `send_message` and `Listener` apply the service's profile on all three carriers, with the dev32 tail and an open block on FIRST (docs/SECURITY.md). Tests M1 to M12, the ooRexx message test. Forged close-acknowledgements are dropped (M8), which also closes gap 10 for protected services.
- The second dev32 security review: nine findings fixed (docs/SECURITY.md, "Second review"). Tests P21 to P27 and the ooRexx hostile-directory test.

## Closed in dev32

- **Per-service protection for sessions (decision D-07).** Authentication or encryption is chosen by the named service's profile:
  - per-packet AEAD tails;
  - per-context keys from HKDF;
  - opens bound to a key, a nonce and a time window;
  - anti-replay;
  - downgrade refused (AUTH_REQUIRED).

  Keys come from the Identity Directory over LDAP first, and from a key file when LDAP is unavailable. See docs/SECURITY.md, and tests P1 to P13 plus the ooRexx LDAP test. This meets the second gateway gate for sessions; gap 1 remains for messages and streams.

## Closed in dev31

- **Persistent interactive contexts** (`include/xtp/xtp_session.hpp`, `rexx/XtpSession.cls`, `docs/SESSIONS.md`). One KEY carries both directions, with:
  - delivery as data arrives;
  - message boundaries (EOM);
  - per-direction close (WCLOSE/RCLOSE);
  - flow control from the reader;
  - selective repair;
  - SYNC/ECHO timing;
  - keepalive and dead-peer detection;
  - abort.

  This is the second XTP gateway gate in `docs/XTP_GATEWAY_SPEC.md` (G1), now met with LOCAL_PASS evidence: tests S1 to S14, including raw36 and L2 on loopback, plus the ooRexx test. Authentication (gap 1) remains the gate that is still open.
- **DSEQ is reported after delivery, for sessions.** A session CNTL's DSEQ is the number of bytes the application has read, and ALLOC follows it. Gap 3 still applies to the older message and stream paths.
- **Hostile-peer bounds for sessions.** An independent review before commit found ten defects; all are fixed, with tests S15 to S21. See docs/SESSIONS.md, wire item 7.
- **The stream sender could resend for ever.** A dev28 to dev30 stream sender whose receiver had reported a SPAN and then gone silent never gave up: the early wake to repair a SPAN hole never counted as a timeout. It was found when test S3 hung once in about 35 runs, after the listener had delivered and stopped reading. The sender now fails after (retries + 1) × 8 × timeout_ms without progress. New test: segmentation S10. dev30 is still running it at 60 s; dev31 fails cleanly at 3.2 s.

## Closed in dev30

- DIAG could be used as a reflector, and leaked detail. dev29 answered every refused packet, from any source including a forged one, with a DIAG up to 80 bytes for a 48-byte FIRST, carrying the requested service name or the parser's message. dev30 sends only the VALUE name, never more bytes than the packet that caused it, and at most 10 per second per peer host (burst 20) and 100 per second in total. Tests H1 to H6; dev29 fails H1, H2a, H2b and H3a.
- VALUEs 16 to 23 reserved for gateway refusals, at the gateway spec's request.

## Closed in dev29

- SYNC/ECHO status handshake on unicast streams: context-bound status, exact tail-loss repair, RTT-timed waits with backoff. It fixes the dev28 silent loss where a stale close from an earlier context completed a new transfer.
- DIAG on refusal (service not admitted, oversize, malformed); senders fail fast with the reason.

## Closed in dev28

- Selective retransmission for unicast streams: NSPAN/SPAN in CNTL (the XTP 3.4 fields), receiver out-of-order store, sender selective repeat with go-back-N fallback for dev27 receivers. Under 20%/14% loss, 49 resends where dev27 needed 8,867.
- A retransmitted FIRST no longer resets a stream, and one resent after completion re-sends the close.

## Closed in dev27

- Unicast segmentation. FIRST+DATA streams with carrier-aware segment size; L2 is no longer bounded by the MTU. Tests S1 to S6.

## Closed in dev26 that the spec review also raised

- Replay keyed on KEY alone, never expiring, and dropping colliding multipath chunks. Now keyed on (peer host, KEY, payload digest) in a bounded window. Test E7.
- Close-ACK sent before the payload was decoded. Now decoded first. Test E6.
- The return bit on a returned KEY was never checked. Now required. Test N1-RTN.
