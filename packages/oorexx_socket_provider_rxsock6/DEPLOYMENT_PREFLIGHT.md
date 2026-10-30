# RxSock6 deployment preflight

The package now contains a fail-closed deployment preflight:

```sh
OOREXX_ROOT=/path/to/oorexx/usr/local \
SOCKET_PROVIDER_SRC=/path/to/socket-provider/src \
RXSOCK6_ROOT=/path/to/rxsock6 \
  tests/deployment_preflight.sh
```

It verifies the deployment rather than trusting package labels:

1. the requested ooRexx executable exists;
2. `socket6.cls` exists;
3. a native RxSock6 shared library exists;
4. the host kernel exposes IPv6;
5. the historical checked-in Socket Provider adapter still passes its TCP6
   contract, negotiation and real loopback qualification;
6. two native `.Socket6` UDP sockets bind to `::1`, obtain real ephemeral
   ports, connect, and exchange `PING/PONG` using inherited Socket send/recv.

The last step is intentionally a **native class-layer** UDP6 proof. It does not
pretend that the missing RxSock6 Socket Provider dev3 source has appeared.

Successful output ends with:

```text
RXSOCK6_PREFLIGHT_TCP6_PROVIDER=PASS
RXSOCK6_PREFLIGHT_UDP6_NATIVE=PASS
RXSOCK6_PREFLIGHT_PROVIDER_DEV3_SOURCE=NOT_ASSERTED
PASS RXSOCK6_DEPLOYMENT_PREFLIGHT
```

That distinction is operationally important. A deployment can prove that its
installed `socket6.cls` / native library supports the UDP6 mechanics required
by later provider work without relabelling the historical checked-in provider
source as dev3.

## ED209 / internode boundary

This preflight is **not** an XTP carrier substitution. Current ED209 internode
traffic retains its established XTP carrier policy: local MI↔MU Layer 2,
non-GCP MU↔MU native protocol 36, and GCP-involving MU↔MU UDP 62801. RxSock6 is
a sibling IPv6 socket capability for platform consumers; it does not replace
that transport contract.
