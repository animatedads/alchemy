# Storage network listener and multicast frame hardening — 2026-10-27

This changes only the optional `StorageNetworkServices.cls` boundary. A normal unbound listener continues to select the supplied Socket Provider (TCP/IP, Unix, QueueRexx or another provider). An explicit logical named peer requires the named manager. If that manager is unavailable or the peer name is empty, the service fails closed; it does not open a raw listener.

Multicast SEARCH/OFFER carries a digest and a single bounded ASCII challenge token. A short send is not a completed frame. An OFFER remains an untrusted hint, never replica evidence.

Source and test: `src/StorageNetworkServices.cls`, `tests/test_network_listener_discovery.rex`. Existing `tests/test_network_services.rex` also passed under the user-supplied ooRexx 5.3.0 r13196 debug interpreter, using the Candidate 5 dependency surface. No ED209 XTP FIRST-to-KEY route, multicast, rate governor or Azure Git backup has been field tested here.

The Library sphere v0.8 is continued separately as v0.9; this GitHub projection is not a full publication of the 36-file sphere.
