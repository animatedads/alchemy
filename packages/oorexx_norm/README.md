# ooRexx NORM Socket Provider v0.1-dev1

This package makes NRL NORM an ordinary provider behind the portfolio SocketProvider contract.  Applications retain the same logical-address -> selector -> endpoint call shape used by the existing TCP/UNIX/TLS/XTP work.

## Boundary

`NormSocketProvider.cls` owns the Rexx provider shape. `liboorexx_norm_native.so` owns libnorm handles and byte-buffer lifetime. libnorm owns NORM session, NACK/FEC repair and UDP/IP multicast mechanics. The application never calls `NormCreateSession()`, `NormStartReceiver()`, `IP_ADD_MEMBERSHIP`, or related native operations.

A NORM SocketAddress preserves group/session address, port, local multicast interface, optional SSM source and NORM node id as structured values. It is not flattened to `host:port`.

## Build

Requires ooRexx 5.x development headers and NRL NORM (`normApi.h` plus `libnorm`).

```sh
make OOREXX_ROOT=/usr/local NORM_ROOT=/opt/norm
```

The native sender retains every enqueued data buffer until libnorm reports `NORM_TX_OBJECT_PURGED`, because NORM's enqueue API requires the application buffer to remain valid for the transport object's lifetime.

## Qualification

Run `tests/environment_test.sh`. Set `NORM_LIVE_TEST=1` to execute real multicast on the selected interface. The live test uses one receiver and one sender through `SocketSelector`; it does not call a NORM-specific send API from application code.

The supplied environment script is intentionally complete: Rexx compile checks, address-contract test, native build, libnorm identity, and optional actual multicast transfer.
