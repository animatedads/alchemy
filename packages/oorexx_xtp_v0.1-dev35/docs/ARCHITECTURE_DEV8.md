# XTP dev8 — SocketSelector integration

The standard ooRexx Socket Provider is now the application boundary. XTP is a
transport family backend, not a parallel selector.

- `SocketSelector` resolves the logical service to an XTP SocketAddress.
- `RexxXtpSocketBinding` dispatches to `XtpSocketBackend`.
- `XtpSocketBackend` creates an XTP provider socket.
- XTP send delegates to `libxtp::SocketProvider`, which calls `best_connect()`.
- Explicit XTP L3/L4 routes and metal-first L2 preference remain owned by
  libxtp.
- Route wire filters (`zero-block`, `crunch`) remain below SocketSelector and
  above XTP packetisation.

This removes direct RxSock assumptions from XTP callers and preserves the
portfolio-wide protocol-independent SocketAddress/SocketEndpoint model.
