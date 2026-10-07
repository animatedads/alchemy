# Queue Fabric encrypted inter-node transport — v0.9-dev6

## Purpose

`queue.transport/2` is the remote Queue Fabric link intended for traffic between separately administered or separately networked execution nodes. It does not change in-process queue operations, durable queue formats, placement authority, WLU authority, or queue/channel ownership.

The transport is fail-closed: a remote peer must satisfy **both** source-IP admission and cryptographic peer authentication before a queue command is accepted.

## Connection admission order

1. TCP connection is accepted by the listener.
2. The numeric source address is obtained from the accepted socket with `getPeerName`.
3. The source is normalized through the development cut's canonical IPv4 policy. CIDR, hostnames, IPv6, leading-zero forms, malformed/out-of-range addresses and `0.0.0.0` are not valid application allowlist entries. If the exact source IP is not present in the listener's aggregate trusted-peer allowlist, the socket is closed immediately. No HELLO frame is read and no cryptographic work is performed.
4. HELLO identifies source manager, destination manager, receiver channel, principal and key id and is authenticated with HMAC-SHA-512.
5. The selected trusted peer is checked again: the actual source IP must be in that peer's own allowlist.
6. Server challenge is authenticated with HMAC-SHA-512.
7. Both sides derive directional per-connection keys from the configured transport PSK plus the complete authenticated transcript and both 256-bit random nonces.
8. PROBE, DELIVER, HEALTH and RESULT bodies are ChaCha20 encrypted and then authenticated with a separate HMAC-SHA-512 key (encrypt-then-MAC). Authentication is verified before decryption.

An IP address is an admission fact, not an identity credential. Passing the IP rule never bypasses the cryptographic peer proof or Queue Fabric receiver/ACL checks.

Re-registering the same trusted peer identity replaces that peer and rebuilds the listener-wide pre-authentication address set from the current peer table. An IP removed from a peer therefore cannot linger merely because it was previously trusted.

## Key derivation and direction separation

The connection root is HMAC-SHA-512 over a protocol-labelled transcript. Separate HMAC labels derive:

- client-to-server ChaCha20 key;
- client-to-server HMAC key;
- client-to-server nonce;
- server-to-client ChaCha20 key;
- server-to-client HMAC key;
- server-to-client nonce.

The client and server therefore never reuse the same stream-cipher key/nonce pair in opposite directions. Queue Fabric currently performs one command/response exchange per TCP connection, so each derived directional nonce is used once. A secure frame from one connection transcript fails authentication when replayed into a different nonce/transcript-bound session.

The transport key must contain at least 256 bits (64 hexadecimal characters). Existing tests use longer keys as well.

## Security properties and deliberate limitations

Provided the PSK remains secret and `/dev/urandom` remains available, `queue.transport/2` provides payload confidentiality, message integrity, mutual PSK authentication, transcript binding and replay separation between fresh connections. Existing durable `transferId` receipts remain the receiver-side idempotence authority.

This v0.9-dev6 design is **PSK based and does not provide forward secrecy**. Compromise of the long-term PSK can permit decryption of previously recorded sessions if their public handshake nonces/transcript were captured. The project Crypto X25519 surface is intentionally not used because its documented semantics are not the standard clamped X25519 protocol. A future standard TLS 1.3 or standards-qualified ephemeral key-agreement transport can add forward secrecy without changing Queue Fabric delivery semantics.

The HELLO and CHALLENGE handshake metadata is authenticated but not confidential. Queue payloads, probe/result bodies and application details are encrypted after the challenge.

## OCI deployment rule

For two Oracle Cloud nodes, prefer private VCN addresses for the queue path. Apply the restriction twice:

- OCI NSG/security rule: allow inbound TCP on the chosen Queue Fabric port only from the other node's exact private IPv4 `/32` (and reciprocal rule if both nodes accept connections).
- Queue Fabric listener: bind each trusted queue peer to that same exact numeric private IP.

Do not use `0.0.0.0/0` for the Queue Fabric port. If an internet-routed design is unavoidable, use stable/reserved addresses and still retain the application-level allowlist.

## Allocator relationship

Job-to-Node Allocator does not own or implement transport encryption. If a job can be dispatched only to nodes that support this remote path, publish a durable node ability such as `QUEUE_SECURE_TRANSPORT_V2` and put that ability in the job's hard requirements. The existing allocator already treats required abilities as hard eligibility; capacity or policy score cannot compensate for its absence.

## Secret authority

`keyId` is an identifier, not permission. The current transport constructor retains the established `keyHex` compatibility surface so the Queue Fabric test suite and existing callers can exercise the new wire protocol. Production wiring should obtain that material through Secret Broker by reference and should not persist or expose raw transport keys in queue definitions, allocator capability statements, NoSQL projections, logs or command lines. Secret-reference-native endpoint registration/key rotation remains a separate integration increment rather than duplicating Secret Broker authority in Queue Fabric.
