# Qualification status

Source-integrated v0.1-dev2; runtime qualification pending.

Included deterministic qualification:

- exact `ApiUrl` and `ApiRequest` objects reach the injected route resolver;
- exact `SocketAddress` object reaches `SocketProvider~streamSenderAt`;
- selected address identity survives into the carrier;
- write/read/close delegate through the selected provider stream;
- provider-native PUMP/POLL/SELECT is required for bounded TLS progress;
- absent route fails closed;
- selected stream without readiness support fails closed and is closed.

Runtime execution remains pending until ooRexx 5.3.0 r13196 and exact current
source roots are available to the executor. No live HTTPS-over-XTP claim is made.


## dev2 deterministic contract

Added `test_socket_intention_route_resolver.rex` covering:

- fresh negotiation on every resolve; no permanent startup route cache;
- exact `ApiRouteRequirement` and `ApiRequest` object preservation into Socket negotiation metadata/context;
- semantic `socketLogicalName` projection;
- raw-stream requirement with `requireSecure=false` because API Client owns TLS above the carrier;
- default raw carrier schemes XTP and TCP, with TLS excluded to prevent TLS-inside-TLS;
- selected address may change between consecutive negotiations;
- NO_OFFER fails closed;
- URL host fallback exists only when no semantic logical name/resolver is supplied.

Runtime execution is still pending. Source integration is not a live HTTPS-over-XTP claim.
