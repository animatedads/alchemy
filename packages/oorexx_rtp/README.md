# ooRexx RTP v0.1-dev7

Dev7 aligns the independent RTP instrumentation adapter with Instrumentation Mesh dev8 explicit correlation/context semantics. RTP protocol, carrier and lifecycle behaviour are otherwise unchanged from dev6.

RTP is a shared protocol layer, not part of SIP and not a socket implementation.

Dev2 removes native UDP socket ownership from `liboorexx_rtp.so`. The native
library now owns only timing-sensitive RTP packet framing and G.711 conversion.
Carrier acquisition is delegated to the estate `SocketProvider` API.

```text
SIP / RTSP / media application
          |
          v
        RTP
   packet + codec
          |
   RtpEndpoint
          |
   SocketProvider
          |
 RxSock UDP / future qualified datagram binding
```

`RtpReceiver` and `RtpSender` remain independent objects sharing an endpoint.
Stopping either does not stop the other and neither owns the endpoint lifecycle.

## dev4 — Instrumentation Mesh

`src/rtp_instrumentation.cls` exposes RTP-owned operational facts through
`instrumentation.mesh/0.1`. RTP endpoint, receiver and sender state plus frame,
sample, byte and drop counters remain separate from SIP instrumentation.

The instrumentation adapter is optional and external to the dependency-free RTP
packet/media core. It consumes the same structured event sink seam used by
logging and does not alter RTP carrier or lifecycle authority.


## dev6 — carrier telemetry boundary

RTP continues to own RTP framing and media counters only. When its injected SocketProvider uses the shared `socket.telemetry/0.1` decorator, carrier acquisition, datagram I/O bytes/calls, close and multicast membership are observed below RTP without duplicating those counters in `RtpInstrumentationSink`. The SIP dev13 qualification exercises RTP and SIP through one observed provider and proves those layers remain independently instrumented.