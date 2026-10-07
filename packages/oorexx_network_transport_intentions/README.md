# ooRexx Network Transport Intentions v0.1-dev1

Read-only specialist intention surface over the existing Socket Provider and XTP authorities.

The package deliberately separates three facts:

1. a logical service currently resolves to a socket address/family;
2. that family advertises capabilities such as secure or multicast;
3. XTP route authority currently advertises candidate routes and a preferred route.

It does not acquire sockets, connect/listen, probe networks, choose XTP routes, execute `xtp-admin`, or mutate route state. Socket Provider objects (`SocketAddress`, `SocketFamily`, `SocketCapabilities`) and XTP route objects (`XTPRoute`) are retained by identity.

## Surface

`NetworkTransportIntentionProvider~discover(context)` publishes operations including:

- `LIST_LOGICAL_SERVICES`
- `GET_SERVICE_TRANSPORT`
- `GET_TRANSPORT_CAPABILITIES`
- `EXPLAIN_SERVICE_TRANSPORT`
- `LIST_XTP_ROUTES`
- `GET_XTP_BEST_ROUTE`
- `EXPLAIN_XTP_ROUTE`

`SocketProviderTransportAuthority` performs only address resolution through the existing `SocketAddressProvider` contract. It never calls `SocketProvider~sender()` or `listener()`.

XTP route discovery is injected through `NetworkXtpRouteAuthority`. This is intentional because the supplied XTP dev6 ooRexx administration façade shells through `xtp-admin`; management intentions must bind to authoritative route state rather than make that shortcut architectural.

`NetworkTransportRelationshipProvider` publishes domain-owned relationships such as `USES_SOCKET_ADDRESS`, `USES_TRANSPORT_FAMILY`, and `HAS_XTP_ROUTE`. Management treats those names as opaque.

## Qualification

```sh
MANAGEMENT_INTENTION_ROOT=/path/to/oorexx_management_intention_discovery_v0.1-dev5 \
REXX_BIN=/path/to/rexx \
  ./tools/run_environment_test.sh
```
