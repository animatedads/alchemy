# Socket Provider v0.1-dev14 compatibility note

Checked against Library artifacts on 2026-10-07:

- `oorexx_socket_provider_v0.1-dev14(1).zip` SHA-256 `39d9f5f6851bf134acb9cc372126a1f53d19eeff4148b28d353bbe76f5451abe`
- `oorexx_xtp_v0.1-dev18.zip` (the dev14 provider validation records XTP dev18 SHA-256 `970de72417ed0e10a7cdc45eac9f33d7487ddd41594877837da3799986412ec8`)

Socket Provider now retains generic `descriptor`, listener `waitReady`, `tryAccept`, and sender `waitDrained` delegation. That is sufficient for native providers which expose those methods. The concrete `RxSockTcpBinding` sender, however, wraps an ordinary ooRexx `.Socket`; `ProviderSocketConnection~descriptor` therefore returns `-1` because that object does not expose the provider `DESCRIPTOR` method. There is also no provider-neutral sender `waitReady` method.

TN3270 needs bounded readable-wait semantics so a quiet terminal never blocks the owner process indefinitely. Candidate10 therefore **does not** migrate TN3270 to Socket Provider yet and **does not** use `SocketEndpoint~raw` as an escape hatch. `TcpTerminalTransport` remains the qualified path. When Socket Provider projects readable readiness for ordinary TCP connections, Terminal Machine can adopt it without changing 3270 semantics or ownership.
