# Socket Provider dev8 compatibility

Library review on 2026-10-07 found `oorexx_socket_provider_v0.1-dev8.zip` as the
current Socket Provider package. Its SHA-256 is
`77dcaa98a09aed9410ede749cfadce3a0bbd9a9e7ed1ed3d24aa6e7483238898`.

Dev8 preserves the XTP family while adding NORM as a sibling provider and
retains the discovery-first, per-turn capability model introduced in dev6.
XTP dev12 therefore does not add an application-visible transport API or absorb
NORM. It remains an implementation behind the common `SocketSelector` /
`SocketAddress` / `SocketEndpoint` boundary. The current dev8 provider classes
are vendored solely for self-contained compatibility qualification.

XTP path health is intentionally below dynamic Socket Intention discovery:
route configuration says what is permitted; `PathHealthTable` says what is
currently admissible; the XTP provider projects the resulting capability upward.


## dev14 historical correction

At dev14, Socket Provider profiles that advertised XTP multicast were stale relative to libxtp because multicast had not yet been implemented. That warning remains part of the historical compatibility record; dev15 supersedes it with executable multicast support and a current dev15 capability profile.


### Current status (dev15)

The warning above records the dev14 boundary. It is superseded for current deployment by libxtp dev15 and Socket Provider dev10: XTP MULTI is implemented, qualified, and advertised by the `xtpDev15Rexx` profile.


### Current status (dev16 / Socket Provider dev11)

libxtp dev16 adds FIRST+DATA multicast streaming. Socket Provider dev11 therefore separates `multicastStream` from the generic `stream` and `multicast` flags: historical dev15 remains multicast-message-capable but cannot satisfy a multicast-stream requirement, while the dev16 profile can.

### Current status (dev17 / Socket Provider dev12+)

The current common Socket Provider contract does **not** introduce a separate
`multicastStream` capability.  Multicast streaming is requested as the
conjunction `requireStream=true` and `requireMulticast=true`.  XTP dev17
advertises both capabilities and is therefore eligible; older XTP profiles
remain historical compatibility records.  This keeps XTP-specific evolution
behind the common protocol-independent selector contract.
