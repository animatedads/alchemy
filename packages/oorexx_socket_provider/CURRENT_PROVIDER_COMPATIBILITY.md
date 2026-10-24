# Current Socket Provider family compatibility — 2026-10-24

This file is an estate compatibility snapshot. It does not change the historical version label of the SocketProvider source directory in this repository.

| Provider | Current evidenced package | Relationship to current SocketProvider authority |
|---|---|---|
| SocketProvider common authority | `oorexx_socket_provider_v0.1-dev16.zip` SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2` | current external/common artifact authority |
| NORM | `oorexx_norm_v0.1-dev3.zip` SHA-256 `d997007d35c7527eb40d6d62516cee036ed2d1a27fb1edbe32bdf4389abcd231` | live requalified against dev16; reliable multicast + explicit membership + descriptor readiness |
| XTP | `oorexx_xtp_v0.1-dev25.zip` SHA-256 `7f6ab3d1167d5fd3131c7e6d6e9ea8d8c6115106ea9df89d41357ef56773b80b` | current development head; XTP-owned route/multipath/pacing/multicast mechanics |
| QUIC | `oorexx_quic_socket_provider_v0.1-dev3` | sibling provider; existing sphere records current qualification |
| IPv4 multicast | `oorexx_ip_multicast_v0.1-dev1` | injected RFC multicast membership backend |
| IPv6 TCP | rxsock6 sibling binding | full IPv6 address object retained |

Common invariants remain unchanged: SocketSelector is acquisition authority; applications declare requirements rather than protocol mechanics; provider-specific transport behaviour stays below the provider boundary; full selected SocketAddress identity is preserved.

The repository's `packages/oorexx_socket_provider` source currently carries older historical version labels. That source must not be renamed to dev16 without the exact dev16 source publication.
