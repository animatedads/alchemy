# NORM provider compatibility — current evidence 2026-10-24

NORM remains a first-class sibling provider behind the common SocketProvider boundary. The current NORM source release is `oorexx_norm_v0.1-dev3.zip`, SHA-256 `d997007d35c7527eb40d6d62516cee036ed2d1a27fb1edbe32bdf4389abcd231`.

The common NORM-facing contracts are:

- `SocketTransportKind~NORM`, NORM scheme/family and complete NORM `SocketAddress` values;
- `socket.multicast.membership/0.1` with explicit join/leave and membership lifetime independent of listeners;
- provider-neutral `descriptor`, `waitReady`, `tryAccept` and sender `waitDrained` delegation.

NORM owns libnorm instance/session creation, multicast interface and SSM state, NACK/FEC repair, object-buffer lifetime, and native descriptor draining. Applications do not call libnorm directly.

## Current compatibility authority

Current SocketProvider artifact authority is `oorexx_socket_provider_v0.1-dev16.zip`, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

The unchanged NORM dev3 archive was live-requalified against dev16 on 2026-10-10 under ooRexx r13196 + libnorm 1.5.7. ASM, SSM, NACK repair with 10% induced loss/parity=0, IPv6 multicast, descriptor readiness and membership lifecycle all passed.

The source directory containing this file still has older historical SocketProvider version labels. Do not relabel that source as dev16 without publishing the exact dev16 source tree.
