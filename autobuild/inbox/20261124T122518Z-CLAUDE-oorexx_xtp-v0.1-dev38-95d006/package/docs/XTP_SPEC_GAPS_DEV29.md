# XTP specification gaps after dev29

**Architecture:** Tom Dyer. **Implementation reviewed:** libxtp dev25 to dev29 (ChatGPT and Codex to dev25; dev26 to dev29 by Claude). **Written by:** Claude (Opus 5.5), 24 October 2026.

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
| 1 | No authentication of FIRST or CNTL. This is an Alchemy requirement, not an XTP one: XTP itself appears to have none. | HIGH | The gateway contract (review section 4): MAC over the header, service, KEY, ROUTE, nonce and time window. |
| 2 | Single-FIRST unicast and multicast still wait a fixed `timeout_ms` with no backoff; RTT-timed waits (dev29) cover unicast streams only. | LOW | Send a SYNC with single FIRSTs too, or use the stream path for every unicast send. |
| 3 | DSEQ is reported equal to RSEQ before the application has the data. | MEDIUM | Report DSEQ only after delivery. |
| 4 | The address segment is optional and detected by sniffing. Only third-party senders are at risk, since `send_message` always wraps the payload in an `XWF1` envelope. 0xA11C does not fit the 4.0 8-bit AFORMAT. | MEDIUM | Always emit a segment, using the NULL format when no service is named; under 4.0, use a private AFORMAT of 128 or above. |
| 5 | No traffic specification or service type in FIRST, and no MAXDATA/MTU negotiation. | MEDIUM | Emit at least MAXDATA and SERVICE; refuse an unsupported one with DIAG. |
| 6 | Only the abbreviated transaction close exists. There is no context state machine and no CTIMER keepalive or reaping. | MEDIUM | A context table with CTIMER. dev26's bounded replay window is an interim substitute for reaping. |
| 7 | Multicast CNTL replies are not slotted (no random delay or damping), so implosion risk grows with the receiver count. | LOW-MEDIUM | Random slot delay plus suppression when a peer's CNTL covers the same state. |
| 8 | BTAG, DADDR, RES, NOCHECK, DREQ and ETAG are never emitted, and unknown flags are not rejected. TTL is fixed at 64 (0.64 s). | LOW | One wire-constants table with a cited source for each bit; reject illegal flags. |
| 9 | Multicast is still go-back-N; selective repeat (dev28) covers unicast streams only. Multicast receivers would need per-receiver SPANs and the sender a union of holes. | MEDIUM | Reuse dev28's receiver store and SPAN encoding in the multicast listener. |
| 10 | SYNC/ECHO context binding protects streams only after the peer has echoed. Before the first echo arrives (the first round trip), and with peers that never echo (dev28 and earlier), an ECHO=0 CNTL is still believed. | MEDIUM | Authenticated CNTL (the gateway contract) closes this for every peer. |
| 11 | Several dev25-era test scripts use Python (run_tests.sh, test_multicast*.sh, test_multipath.sh, test_path_health.sh, test_requalification.sh, test_capability_contract.sh). No dev26 to dev29 code depends on it. | LOW | Port the checks to shell or ooRexx when those suites are next touched. |

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
