# MAS host ConnectSelector binding — PRE23

MAS guest framing and X'75' remain unchanged. ConnectSelector dev6 is the sole application-level choice between DirectCall, RPC, QueueFabric and qualified continuity routes on the host side. MAS does not implement a competing selector and does not silently retry on another provider after execution begins or becomes uncertain.

`MasConnectSelectorPort` constructs MAS-owned intentions and delegates selection to ConnectSelector. RpcServiceCore publication is performed by `MasRpcServicePublisher`; actual local dispatcher adaptation is the upstream `ConnectRpcDispatchAdapter` from ConnectSelector dev6.

The current MAS Queue personality is **not** mapped automatically to QueueFabric. `QPUT` returns synchronous depth and `QGET/QDEPTH` require replies, whereas the current Queue adapter proves enqueue semantics. A future request/reply queue profile must explicitly define correlation, reply destination, deadline, expiry, replay and uncertain-outcome behavior.

## SMTP production authority

SMTP Secure Stack dev11 retains the MAS security boundary: host-attributed identity and host-side authorization are required for production sign/send. Guest `VERIFIED`, `AUTHORIZED` and `EGRESS` values are qualification data only and never authority evidence.
