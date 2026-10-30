# XTP v0.1-dev20 — ROUTE / XROUTE endpoint exchange and current SocketSelector reconciliation

Dev20 adds the XTP 3.4 common-header `ROUTE` field and CNTL `XROUTE` exchange to the executable libxtp transaction path.

## Wire mapping

- Common header bytes 20..23 carry `ROUTE`.
- CNTL control-segment bytes 32..35 carry `XROUTE`.
- A receiver returns the incoming ROUTE in return form by setting the high direction bit.
- `ListenOptions.exchange_route_value` optionally offers a replacement route value in XROUTE.
- `SendResult.peer_return_route` and `SendResult.peer_xroute` expose both values to callers.

This is endpoint route exchange, not a claim that dev20 already contains the full XTP multi-hop router. Router forwarding, per-hop address substitution and route-cache forwarding remain a separate implementation gate.

## ooRexx hooks

`XtpSocketBackend~routeSender(address, routeValue)` and `~routeListener(address, exchangeRoute, backlog)` expose the same libxtp mechanism through the SocketSelector provider boundary. `XtpProviderSocket~lastResult['XROUTE']` records the peer offer.

The ordinary protocol-independent SocketSelector API remains unchanged.

## Current Library baseline

The 2026-10-13 transport reconciliation names Socket Provider v0.1-dev16 as the common selector baseline and XTP dev19 as the then-current XTP head. Dev20 preserves that boundary. The older vendored SocketProvider files remain a qualification shim only and are not the authority for the common selector contract.

## Repair

Dev20 also corrects `XtpProviderListener~close` to call `xtpNativeListenerClose`. The previous class incorrectly used the multicast-listener close entry point.
