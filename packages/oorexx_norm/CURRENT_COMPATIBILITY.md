# Current NORM compatibility — 2026-10-24

The published source package remains `oorexx_norm_v0.1-dev3` (SHA-256 `d997007d35c7527eb40d6d62516cee036ed2d1a27fb1edbe32bdf4389abcd231`). Its package metadata records `oorexx_socket_provider >= 0.1-dev10`, which is the historical development floor and must not be rewritten.

Current common SocketProvider authority is `oorexx_socket_provider_v0.1-dev16.zip`, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

A fresh 2026-10-10 qualification ran the unchanged NORM dev3 archive against SocketProvider dev16 under ooRexx 5.3.0 r13196 and live libnorm 1.5.7. It passed provider-neutral descriptor/readiness, exact SocketAddress identity, explicit membership/listener lifetime separation, SocketSelector membership acquisition, IPv4 ASM, IPv4 SSM, a 10% induced-loss/no-parity NACK-repair forcing case, and IPv6 multicast.

This file records compatibility evidence only. It does not claim the GitHub SocketProvider source directory is dev16: that directory has older historical source labels and must not be relabelled without the exact dev16 source publication.

Current sibling transport context: XTP development head is v0.1-dev25. XTP route/multipath/pacing/multicast mechanics remain XTP-owned; they do not change NORM's common SocketProvider boundary.
