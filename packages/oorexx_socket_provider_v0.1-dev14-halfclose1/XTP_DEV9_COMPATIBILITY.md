# XTP dev9 compatibility

Qualified against the supplied `oorexx_xtp_v0.1-dev9` source.

The XTP package's generic-facing boundary remains:

```text
SocketSelector / SocketProvider
        |
RexxXtpSocketBinding
        |
XtpSocketBackend
        |
libxtp route selection
```

The current XTP dev9 Rexx backend implements sender construction and deliberately
fails listener construction. The native library itself now has a persistent receive
Listener, but the Rexx bridge does not yet retain that native listener across accepts.
Socket negotiation therefore advertises current implementation capability, not merely
protocol-family capability.

This is intentionally dynamic evidence. When a later XTP package provides a persistent
Rexx listener bridge, its offer capability can set `listener=.true` without changing
the Socket Intention contract or application code.
