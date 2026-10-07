# XTP v0.1-dev10 — native ooRexx socket binding

Dev10 removes the shell-process boundary from the ooRexx SocketSelector XTP provider.

- `liboorexx_xtp_native.so` is a typed ooRexx external library built directly over `libxtp`.
- Rexx sender calls `xtpNativeSend()` in-process with binary-safe Rexx strings.
- Rexx listener owns a persistent native `xtp::Listener` handle across `accept()` calls, retaining replay state and carrier state.
- The Rexx object layer remains the application/admin surface; native handles are private implementation state.
- `SocketSelector` remains transport-independent and does not duplicate XTP `best_connect()` logic.

The binding therefore preserves the intended split: Rexx carries the endpoint objects and policy-facing semantics, while `libxtp` owns XTP packet/route/filter/carrier mechanics.
