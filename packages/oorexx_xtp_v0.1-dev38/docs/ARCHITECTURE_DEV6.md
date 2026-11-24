# SUPERSEDED by ARCHITECTURE_DEV7.md


```text
ooRexx / SocketSelector
        |
    XTP provider
        |
  libxtp route graph ------ administrative XTPRoute objects
        |
  WireFilterChain          zero-block -> crunch -> future filters
        |
  XTP sequencing/framing
        |
   L2 / L3 / L4 carrier
```

Rules locked in dev6:

1. Applications request XTP; they do not select raw packet APIs themselves.
2. Direct metal L2 is preferred when an allowed route exists.
3. Explicit L3 (`raw36`) and L4 (`udp`, VPN-backed or future encapsulations) cross-path routes are library state.
4. Wire representation filters are transport-independent and run before XTP packetisation.
5. The ooRexx administration façade manipulates the same route state used by native callers.
6. Kernel residency is a provider implementation choice.  The public library/Rexx contract must survive transition from userspace to `xtp.ko` / `CONFIG_XTP=y`.
7. The dev6 kernel file is only the residency/build hook.  It must not be represented as a complete AF_XTP implementation until packet registration, socket family, lifetime and concurrency qualification exist.
