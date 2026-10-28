# Current XTP integration — libxtp dev17

Socket Provider dev13 preserves the dev12 common selector API and updates only
the current XTP projection.

Current XTP dev17 evidence advertises sender, listener, stream, and multicast.
A multicast-stream request is expressed by the existing common constraints
`requireStream=true` and `requireMulticast=true`.  No transport-specific
`multicastStream` field is introduced.

The bundled `src/XtpSocketProvider.cls` is the dev17 Rexx adapter.  libxtp
continues to own carrier selection (L2/L3/L4), wire filters, multipath, path
health/requalification, reliable XTP multicast, slowest-receiver ALLOC pacing,
and receiver reject suppression.

Historical profiles such as dev14 remain available and retain multicast=false.
