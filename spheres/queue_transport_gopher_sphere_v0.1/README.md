# Queue Transport Gopher Sphere v0.1

Authoritative project sphere for the ooRexx Queue Fabric inter-node transport workstream.

This sphere is intentionally narrower than Queue Fabric itself. Queue Fabric remains authoritative for queue, channel, topic, durable persistence, receiver ACL and transfer-receipt semantics. The Queue Transport sphere owns the durable knowledge needed to reason correctly about the remote socket boundary: wire identity, source-address admission, authenticated handshake, per-session encryption, replay separation, failure behavior, observability, deployment and integration seams.

## Current implementation baseline

- `oorexx_queue_fabric_v0.9-dev5.zip`
- SHA-256 `05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262`
- aggregate Queue Fabric identity: `queue.fabric/0.9`
- remote socket protocol: `queue.transport/2`
- qualification status: **development continuation candidate**, not sealed/released v0.9

## Core doctrine

1. Remote Queue Fabric traffic crossing the node/network boundary is confidential and authenticated; ordinary in-process Queue Fabric operations are not forced through that transport crypto.
2. A remote peer must pass source-IP admission **and** cryptographic peer authentication. IP is an admission fact, never an identity credential.
3. Source-IP admission is performed on the accepted socket before HELLO parsing. The application allowlist is exact canonical IPv4 only in dev5.
4. HELLO/CHALLENGE authenticate the peer PSK. Fresh client/server nonces and the authenticated transcript derive independent C2S/S2C ChaCha20 keys, HMAC-SHA-512 keys and nonces.
5. Protected command/result bodies use encrypt-then-MAC and verify authentication before decryption.
6. One request/response exchange per TCP connection is part of the current nonce-use design. Reusing a connection for multiple commands requires a new sequence/nonce design and protocol qualification.
7. Cross-session secure-frame replay rejection and durable `transferId` receiver idempotence are separate controls and both remain required.
8. On two OCI nodes, apply exact peer restriction twice: OCI ingress `/32` at the network layer and the same exact numeric address in Queue Fabric's peer allowlist.
9. Job-to-Node Allocator may require an ability such as `QUEUE_SECURE_TRANSPORT_V2` as hard eligibility, but must not implement the encryption itself.
10. Production PSKs belong to Secret Broker authority. `keyId` is metadata; raw key material must not enter allocator capabilities, NoSQL projections, logs, command lines or durable queue definitions.
11. dev5 is PSK-based and does **not** provide forward secrecy.
12. Advancing the remote wire to `queue.transport/2` does not rewrite Queue Fabric durable record identities or QAUTH2 storage formats.

## Retrieval

After loading the sphere:

```text
gopher --profile queue-transport context queue-transport --full
gopher --profile queue-transport lookup topic=transport --sphere queue-transport
```

The profile also includes the ooRexx pack so source-examination services are available when the implementation artifact is present.
