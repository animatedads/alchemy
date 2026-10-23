# Changes in dev3 (2026-10-15)

- Added independent HTTP/2 server-streaming transport engine using libcurl,
  a worker/event queue, bounded buffering and caller-thread event delivery.
- Added new ooRexx streaming client with typed protobuf callbacks, completion,
  fault, cancellation, deadline and maximum-message limits.
- Added dedicated native ooRexx bridge for streaming event operations.
- Added hyper-h2 independent server streaming test fixture, live native stream
  driver and optional ooRexx end-to-end callback qualification script.
- Kept Connect Selector dev5 and Serialization Selector v0.4 as external
  authorities; no copied protobuf codec, routing selector or RPC dispatcher.
- All dev2 sources/tests retained for compatibility.
