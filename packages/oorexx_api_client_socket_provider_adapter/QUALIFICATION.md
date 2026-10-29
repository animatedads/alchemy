# Qualification status

Source candidate v0.1-dev1.

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
