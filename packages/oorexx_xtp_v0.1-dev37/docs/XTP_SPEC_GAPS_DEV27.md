# XTP specification gaps after dev27

**Architecture:** Tom Dyer. **Implementation reviewed:** libxtp dev25 to dev27 (ChatGPT and Codex to dev25; dev26 and dev27 by Claude). **Written by:** Claude (Opus 5.5), 24 October 2026.

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
| 1 | No ECNTL and no SPANS, so there is no selective retransmission. Unicast streams (dev27) and multicast are go-back-N. Under 20% forward and 14% reverse loss, a 200-segment dev27 stream retransmitted 8,867 packets. | HIGH | The receiver keeps out-of-order segments and reports SPANS in ECNTL; the sender resends only the gaps. |
| 2 | No SYNC/ECHO. CNTL control-segment +20 is a constant 1, so a stale or duplicated CNTL is taken as current status. Multicast takes the latest CNTL per receiver unchecked. | HIGH | Add a per-context SYNC counter on SREQ packets, echo it in CNTL, and discard a CNTL whose ECHO doesn't match. |
| 3 | No authentication of FIRST or CNTL. This is an Alchemy requirement, not an XTP one: XTP itself appears to have none. | HIGH | The gateway contract (review section 4): MAC over the header, service, KEY, ROUTE, nonce and time window. |
| 4 | No DIAG. A refused FIRST (unadmitted service, malformed frame) looks like a timeout, and the sender burns 12 × 250 ms. | MEDIUM | Reply with DIAG (code, value) and have the sender fail fast on it. |
| 5 | The wait timer is a fixed 250 ms with 12 retries. There is no RTT measurement and no backoff. | MEDIUM | WTIMER = 2 × RTT from the SYNC/ECHO exchange, doubling on retry. |
| 6 | DSEQ is reported equal to RSEQ before the application has the data. | MEDIUM | Report DSEQ only after delivery. |
| 7 | The address segment is optional and detected by sniffing. Only third-party senders are at risk, since `send_message` always wraps the payload in an `XWF1` envelope. 0xA11C does not fit the 4.0 8-bit AFORMAT. | MEDIUM | Always emit a segment, using the NULL format when no service is named; under 4.0, use a private AFORMAT of 128 or above. |
| 8 | No traffic specification or service type in FIRST, and no MAXDATA/MTU negotiation. | MEDIUM | Emit at least MAXDATA and SERVICE; refuse an unsupported one with DIAG. |
| 9 | Only the abbreviated transaction close exists. There is no context state machine and no CTIMER keepalive or reaping. | MEDIUM | A context table with CTIMER. dev26's bounded replay window is an interim substitute for reaping. |
| 10 | Multicast CNTL replies are not slotted (no random delay or damping), so implosion risk grows with the receiver count. | LOW-MEDIUM | Random slot delay plus suppression when a peer's CNTL covers the same state. |
| 11 | BTAG, DADDR, RES, NOCHECK, DREQ and ETAG are never emitted, and unknown flags are not rejected. TTL is fixed at 64 (0.64 s). | LOW | One wire-constants table with a cited source for each bit; reject illegal flags. |

## Closed in dev27

- Unicast segmentation. FIRST+DATA streams with carrier-aware segment size; L2 is no longer bounded by the MTU. Tests S1 to S6.

## Closed in dev26 that the spec review also raised

- Replay keyed on KEY alone, never expiring, and dropping colliding multipath chunks. Now keyed on (peer host, KEY, payload digest) in a bounded window. Test E7.
- Close-ACK sent before the payload was decoded. Now decoded first. Test E6.
- The return bit on a returned KEY was never checked. Now required. Test N1-RTN.
