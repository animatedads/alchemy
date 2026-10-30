# Socket Provider dependency

The XTP package no longer vendors a historical Socket Provider source snapshot.

The current shared authority is **oorexx_socket_provider v0.1-dev16** (SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`). Supply its class directory through `SOCKET_PROVIDER_DIR` / the normal ooRexx package path when running Rexx integration tests. This avoids creating an XTP-owned fork of the common SocketSelector contract.
