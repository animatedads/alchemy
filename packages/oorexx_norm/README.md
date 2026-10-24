# ooRexx NORM Socket Provider v0.1-dev3

NORM is an ordinary transport provider behind the portfolio `SocketProvider` contract. Applications retain the same logical-address -> selector -> endpoint shape used by TCP/UNIX/TLS/XTP; NORM session, membership, NACK/FEC and wire mechanics terminate below that boundary.

## dev3: descriptor-driven receive and repair qualification

Dev3 consumes Socket Provider v0.1-dev10. Provider listeners now expose transport-neutral `descriptor`, bounded `waitReady(timeoutMilliseconds)` and nonblocking `tryAccept()` delegation. NORM implements these using `NormGetDescriptor()` plus `poll(2)` and nonblocking `NormGetNextEvent(..., false)`. The descriptor remains visible so the portfolio Event Runtime can own readiness scheduling later; NORM does not create a second event framework.

Multicast membership remains explicit and independent of listener lifetime. `join()` creates a `SocketMulticastMembership`; `listenerOn()` attaches without owning the membership; `membership~leave` performs provider-owned teardown.

## ASM, SSM and sender/receiver ownership

The membership request preserves the complete `SocketAddress`, interface and optional source filter. NORM maps receiver interface -> `NormSetMulticastInterface()` and receiver source -> `NormSetSSM()`. dev3 deliberately no longer applies `NormSetSSM()` to senders: SSM source filtering is receiver-membership state, not a sender configuration knob.

Sender receive-port reuse remains enabled before `NormStartSender()` so a sender and receiver may share one multicast session/host. Queued `NormDataEnqueue()` storage is retained until NORM reports object purge.

## Repair/FEC qualification

`qualificationTxLossPercent` is a **qualification-only** address metadata setting. It maps to NORM's built-in `NormSetTxLoss()` test facility and is not part of application policy. The live environment test includes:

- ordinary IPv4 ASM multicast through descriptor readiness;
- IPv4 SSM (`232/8`) with explicit source filtering;
- induced 10% sender loss with `paritySymbols=0`, requiring NACK/retransmission rather than proactive parity to complete the exact 520000-byte object;
- IPv6 multicast when the selected environment exposes an IPv6 multicast-capable interface.

The wire/application contract remains unchanged across those cases.

## Build

Requires ooRexx 5.x headers and NRL NORM 1.5.x headers/library.

```sh
make OOREXX_ROOT=/usr/local NORM_ROOT=/opt/norm
```

For a complete environment qualification:

```sh
SOCKET_PROVIDER_ROOT=/path/oorexx_socket_provider_v0.1-dev10 \
NORM_ROOT=/opt/norm NORM_LIVE_TEST=1 tests/environment_test.sh
```

The environment script exercises the actual native library and network stack; it does not substitute a fake transport for live qualification.
