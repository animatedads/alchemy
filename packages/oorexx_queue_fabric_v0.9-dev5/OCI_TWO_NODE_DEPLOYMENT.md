# Queue Fabric v0.9-dev5 — two-node OCI deployment pattern

This note is intentionally narrow: two Oracle Cloud Infrastructure compute nodes exchanging Queue Fabric traffic over `queue.transport/2`.

## 1. Prefer the private VCN path

Give each Queue Fabric listener a private VNIC/VCN address and use that private address as the peer endpoint. Avoid routing the Queue Fabric port over the public internet when the two nodes can communicate inside the VCN.

Example placeholders:

- Node A / `QM.A`: `10.20.1.10`
- Node B / `QM.B`: `10.20.2.20`
- Queue Fabric TCP port: `47091`

The addresses above are examples only. Put the actual assigned private addresses into both the OCI rule and Queue Fabric peer configuration.

## 2. OCI network admission

For Node B's Queue Fabric listener, allow inbound TCP destination port `47091` only from Node A's exact address `10.20.1.10/32`. If Node A also accepts Queue Fabric connections, apply the reciprocal rule allowing its queue port only from `10.20.2.20/32`.

Do not create a `0.0.0.0/0` ingress rule for the Queue Fabric port. If egress is restricted rather than statefully permitted, add only the corresponding peer/port egress required by the design.

An OCI NSG can alternatively use another NSG as a source when both are in the same VCN, but the intended deployment here deliberately retains an exact IP restriction because application-level Queue Fabric admission is also exact-IP based.

## 3. Queue Fabric application admission

Node B listener sketch:

```rexx
listener = .QueueSocketListener~new("QM.B", "10.20.2.20", 47091, fabricB)
ignore = listener~trustPeer("QM.A", "wire-a", "a-to-b-2026-09", aToBKeyHex, .array~of("10.20.1.10"))
if \listener~start then do
  say "Queue listener failed:" listener~lastError
  exit 20
end
```

Node A outbound sketch:

```rexx
transport = .QueueSocketClientTransport~new("admin")
ignore = transport~registerEndpoint("QM.B", "10.20.2.20", 47091, "wire-a", "a-to-b-2026-09", aToBKeyHex)
```

The listener refuses to start with no trusted source addresses. Every peer source address must be canonical dotted-quad IPv4; CIDR and hostnames are not accepted in the Queue Fabric application allowlist.

If the same peer identity is re-registered with a new address, the aggregate pre-authentication allowlist is rebuilt and the removed address no longer reaches HELLO processing.

## 4. Cryptographic admission and confidentiality

Source IP admission is only the first gate. The peer must also prove the configured PSK through the authenticated HELLO/CHALLENGE exchange. After both random nonces are known, `queue.transport/2` derives separate per-connection C2S/S2C ChaCha20 encryption keys, HMAC-SHA-512 keys and nonces.

`DELIVER`, `PROBE`, `RESULT` and `HEALTH` bodies are encrypted and authenticated. MAC verification occurs before decryption. Queue/receiver ACL and transfer-receipt/idempotence checks remain above the transport.

Use at least a 256-bit transport PSK. If both directions have independently accepting listeners, using distinct A->B and B->A PSKs/key IDs reduces the blast radius of one transport secret.

## 5. Secret handling

`keyId` is safe metadata; the PSK is not. Do not place raw PSKs in allocator capability documents, NoSQL projections, logs, shell history or checked-in configuration. Obtain production key material from the existing Secret Broker by reference and hand it to the transport only at the trusted runtime boundary.

The v0.9-dev5 compatibility constructor still accepts `keyHex` directly; secret-reference-native registration/rotation is intentionally a later integration increment rather than a second secret authority inside Queue Fabric.

## 6. Allocator boundary

The Job-to-Node Allocator should not implement this encryption. Advertise a durable ability such as `QUEUE_SECURE_TRANSPORT_V2` on nodes that actually provide this path and put it in the job's hard requirements when remote dispatch depends on it. Capacity or scoring cannot compensate for a missing required ability.

## 7. Failure expectations

- Wrong source IP: socket closed before HELLO, `ipRejectedCount` increments, no queue mutation.
- Allowed IP but wrong PSK: HELLO authentication fails, no queue mutation.
- Modified ciphertext/tag: authentication fails before decrypt/application processing.
- Replay into a fresh connection: fresh transcript keys reject the secure frame; repeated delivery with a legitimate fresh session remains receiver-idempotent by durable `transferId` receipt.
- No configured peer IPs: listener fails closed at start.

For protocol details and limitations, including the deliberate lack of forward secrecy in this PSK development cut, see `SECURE_TRANSPORT.md`.
