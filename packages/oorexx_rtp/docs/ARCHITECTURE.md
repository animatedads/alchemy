# RTP shared-layer architecture — dev2

## Authority boundary

`RtpEndpoint` requests a UDP datagram endpoint from `SocketProvider`. It never
calls `socket()`, `bind()`, `sendto()` or `recvfrom()` itself. The native RTP
library contains only RTP packet encode/decode and PCMU/PCMA conversion.

The split is intentional:

- SocketProvider owns carrier address and native handle acquisition.
- RTP owns RTP header/payload semantics and media timing state.
- SIP owns SDP negotiation and call signalling.
- `SipInboundAudio` / `SipOutboundAudio` own application-facing media worker
  attachment, not RTP or socket lifetime.

Correlation between these objects does not imply ownership.

## XTP/NORM alignment

XTP and NORM are peer transport families under SocketProvider. RTP does not
embed either protocol and does not infer that every family is an RTP carrier.
Carrier feasibility is a provider capability question. Dev2 qualifies IPv4 UDP
only; future multicast or alternate datagram bindings must be independently
qualified before RTP advertises them.
