# Executable protocol profile in dev2

The XTP packet/control subset remains the dev1 bounded implementation derived from the supplied NASA XTP Revision 3.4 tutorial:

- 24-byte common header and 16-byte common trailer.
- FIRST and CNTL transaction path.
- SREQ/RCLOSE/WCLOSE/EOM fast transaction followed by CNTL RCLOSE/WCLOSE/END.
- KEY, SEQ, ROUTE fields; CNTL RATE, BURST, RSEQ, ALLOC, ECHO, SYNC, TIME, XKEY, XROUTE, NSPAN=0.
- paired LITTLE markers and both big-/little-endian packet representation.
- XTP-style XOR/RXOR DCHECK and HTCHECK.
- retransmit after missing CNTL and duplicate-FIRST suppression by 31-bit initiating KEY.

## Carriers

### UDP

XTP bytes are one UDP datagram. This is the compatibility carrier and remains the regression baseline.

### Native IPv4 protocol 36

`socket(AF_INET, SOCK_RAW, 36)` sends the XTP packet directly as the IPv4 payload. The Linux kernel supplies/removes the IPv4 routing layer; on receive the raw IPv4 header is stripped by the XTP endpoint before XTP parsing. There is no UDP/TCP framing.

This requires `CAP_NET_RAW`. The delivery sandbox used to build dev2 denies that capability, so the code is compiled here but the native-IP runtime PASS must be produced by `qualification/run_environment_test.sh` on a capable host.

### Direct Ethernet / AF_PACKET

Dev2 includes a direct Layer-2 carrier implemented with AF_PACKET using the assigned XTP EtherType `0x817D`. This exercises the same XTP packet engine below IP.

## Still outside dev2

- native XTP ROUTE/XROUTE router process and address substitution across hops;
- SPAN groups/selective retransmission beyond NSPAN=0;
- multicast: implemented in dev15 for the current message/FIRST transaction profile; MULTI flag, reliable acknowledgement quorum with go-back-N whole-message replay, and NOERR mode over L2/L3/L4;
- SORT/deadline scheduling;
- full timer suite beyond the implemented receiver RATE/BURST sender pacing;
- complete packet/flag set and full XTP 3.4 conformance suite.


## dev16 multicast stream profile

- FIRST carries sequence 0 and the first information segment.
- DATA (packet type code 0) carries later information segments.
- MULTI remains set on FIRST and DATA.
- EOM/close and SREQ are carried on the final information packet.
- Reliable receivers require contiguous sequence input; a gap produces a CNTL reject at the receiver's RSEQ.
- Sender recovery is go-back-N from the segment containing the lowest reported RSEQ.
- NOERR is segmented but unrepaired.


## dev18 rate-control profile

CNTL RATE and BURST are now parsed and enforced for reliable multicast streaming. The sender obeys the slowest receiver RATE/BURST while independently obeying the slowest receiver ALLOC. RATE=0xffffffff disables rate pacing.
