# SIP / RTP socket isolation telemetry

SIP dev13 consumes the shared `socket.telemetry/0.1` decorator rather than adding protocol-local socket counters.

```text
SipServer / SipClient              shared RtpEndpoint
          \                           /
           \                         /
            SocketProvider / SocketSelector
                         |
                TelemetrySocketBinding
                         |
                   RxSockUdpBinding
```

The decorator observes acquisition, datagram reads/writes, bytes, close and multicast membership lifecycle. It never parses SIP or RTP and never becomes protocol authority. SIP and RTP continue to emit their own Instrumentation Mesh metrics. Correlation does not imply ownership.

Default socket telemetry deliberately excludes payload, peer/host identity, Unix paths, security-profile names and native endpoint identity.