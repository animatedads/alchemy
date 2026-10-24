# ooRexx BOSH Transport v0.1-dev6

Generic lower-layer BOSH logical-stream transport (XEP-0124 semantics) for ooRexx.

BOSH is deliberately **not** an XMPP package. It consumes an injected HTTP exchange authority and exposes an ordered, reliable, logically persistent bidirectional stream. HTTPS, XTP, TCP, proxying and other underlays remain responsibilities of lower selectors/providers.

dev4 adds the small protocol-neutral extension seam required by upper bindings such as XMPP-over-BOSH: an upper binding may attach namespaced attributes to the initial or subsequent BOSH `<body/>` requests, but may not replace BOSH-owned control attributes. Initial response payload is preserved for the upper binding.

The core has no dependency on XMPP, Messaging/Presence, SocketProvider, TLS, XTP or Instrumentation Mesh. `BoshInstrumentationAdapter.cls` is optional and maps operational facts to the estate `instrumentation.mesh/0.1` API; dev5 is qualified against Instrumentation Mesh v0.1-dev8.

Upper-protocol semantics belong in separate adapter packages. XEP-0206 therefore belongs above this package, not here.


## dev5 observation context

The optional instrumentation observer now exposes the dev8 event timeline in addition to snapshots. Correlation, causation, operation and external context identifiers are preserved only when explicitly supplied by an upper authority. BOSH does not infer a relationship from timing, URI, target domain, carrier choice, HTTP reuse or payload coincidence. Endpoint, stanza/payload and credential material remain excluded from instrumentation.


## dev6 source reconciliation

dev6 does not change the BOSH wire/session semantics introduced through dev5. It repairs the environment qualification path and rebases integration evidence onto the current external estate authorities: Socket Provider dev16, Network Transport Intentions dev3, Instrumentation Mesh dev8 and the XTP dev25 development head.

The released dev5 archive and digest remain historical qualification evidence. The GitHub Socket Provider source tree still identifies as dev14, so dev6 does not relabel or reconstruct dev16 source. Environment qualification requires callers to supply the exact current Socket Provider and Instrumentation Mesh source roots.

The existing HTTPS-over-XTP example remains a composition witness. A concrete generic HTTP/HTTPS exchange authority has not yet been identified in the current first-class package tree, so BOSH does not invent one or import XTP knowledge to close that gap.
