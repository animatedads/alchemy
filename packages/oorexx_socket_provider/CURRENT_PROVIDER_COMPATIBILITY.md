# Current Socket Provider family compatibility — 2026-10-29

This file is an estate compatibility snapshot. It does not change the historical version label of the SocketProvider source directory in this repository.

| Provider | Current evidenced package | Relationship to current SocketProvider authority |
|---|---|---|
| SocketProvider common authority | `oorexx_socket_provider_v0.1-dev16.zip` SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2` | current external/common artifact authority |
| NORM | `oorexx_norm_v0.1-dev3.zip` SHA-256 `d997007d35c7527eb40d6d62516cee036ed2d1a27fb1edbe32bdf4389abcd231` | live requalified against dev16; reliable multicast + explicit membership + descriptor readiness |
| XTP | `packages/oorexx_xtp_v0.1-dev31` | current Git development head; persistent interactive contexts plus named-service, stream, multicast, multipath and carrier mechanics remain XTP-owned |
| QUIC | `oorexx_quic_socket_provider_v0.1-dev3` | sibling provider; existing sphere records current qualification |
| IPv4/IPv6 multicast | current RFC multicast provider line | injected multicast membership backend; common provider does not own RFC socket syscalls |
| IPv6 TCP/UDP | rxsock6 sibling binding | full IPv6 address object retained |

Common invariants remain unchanged: SocketSelector is acquisition authority; applications declare requirements rather than protocol mechanics; provider-specific transport behaviour stays below the provider boundary; full selected SocketAddress identity is preserved.

## XTP authority correction

The Git-canonical `packages/oorexx_socket_provider/PACKAGE.json` still labels the bundled XTP adapter/dev17 profile as current. That is historical package metadata and is **not** current XTP transport authority.

Current XTP source authority is `packages/oorexx_xtp_v0.1-dev31`. Its `DEPENDENCIES.json` explicitly consumes SocketProvider dev16 (SHA-256 above). dev31 adds persistent interactive contexts over UDP, native IPv4 protocol 36 and L2 EtherType 0x817D, while retaining XTP-owned named-service, route, multipath, repair, pacing and multicast mechanics.

Do not copy those XTP mechanics into SocketProvider merely to make the common manifest look current. Consumers that need XTP must resolve the current XTP package/provider against the common SocketProvider contract.

The repository's `packages/oorexx_socket_provider` source still carries historical version `0.1-dev14`. It must not be renamed to dev16 without publishing the exact dev16 source tree.
