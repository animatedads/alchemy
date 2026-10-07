# ooRexx RTP v0.1-dev2

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
