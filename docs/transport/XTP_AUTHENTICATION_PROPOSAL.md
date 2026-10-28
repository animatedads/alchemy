# XTP authentication: where it belongs, and a design (proposal)

**Architecture:** Tom Dyer (decision pending). **Proposal and measurements:** Claude (Opus 5.5), owner of component xtp. **Written by:** Claude (Opus 5.5), 28 October 2026. **Status:** PROPOSAL. Nothing here is implemented.

## The decision

The gateway specification (`docs/XTP_GATEWAY_SPEC.md`, gate G1) has two XTP gates.

- **The persistent interactive context** is met in libxtp dev31 (`packages/oorexx_xtp_v0.1-dev31/docs/SESSIONS.md`).
- **Authentication of FIRST and CNTL** is the one still open.

The question for Tom is whether authentication goes in libxtp or in the gateway. The 23 October review leaned towards the gateway, and libxtp has been crypto-free on purpose.

**Recommendation: split it.** libxtp carries the mechanism: one MAC per packet, keyed per context. The keys, the identities and the policy stay outside libxtp: with the gateway, the estate Crypto key authority and the route and key distribution under D-04. libxtp gains one primitive, HMAC-SHA256 with HKDF from libcrypto. It takes no ciphers, certificates or key management.

## Why not the gateway alone

A gateway can only authenticate traffic it terminates. Most XTP traffic never passes one: MU↔MU (L3), MU↔MI (L2), and Queue, Storage and Memory Fabric transfers. The attacks below are on the transport itself, and only the transport can stop them.

| Attack, possible today by anyone who can send from the peer's address | Effect | Seen in |
| --- | --- | --- |
| Forged close-ACK (CNTL with RCLOSE\|WCLOSE\|END and RSEQ = length) | The sender reports success and the data is never delivered | The same failure as the dev28 stale-close bug, fixed for stale packets only in dev29 |
| Forged CNTL with ALLOC or RSEQ | Stalls a context or frees a sender's buffer early | dev31 bounds the damage (review finding 2); it cannot stop the forgery |
| Forged END or DIAG | Ends any context | dev31 ECHO binding stops a blind forger, not an on-path one |
| Injected DATA in a session | The application reads bytes the peer never sent | dev31 sessions |

The dev26 source binding and the dev29/31 ECHO binding stop off-path and stale packets. Someone on the path, such as a compromised MU, a bridged L2 segment or a shared WAN link, gets through both. The Queue Fabric reconciliation (`docs/transport/XTP_QUEUE_FABRIC_RECONCILIATION_2026-10-16.md`, item 7) also forbids transport degradation that silently weakens peer authentication.

A gateway is still needed for authentication **policy**: who may open what, temporary credentials for foreign peers (gateway mode B), receipts, and revocation. In this split, the gateway issues and revokes keys and libxtp enforces them.

## Cost, measured

On this build host (OpenSSL 3.0.13, one core, a reused HMAC context per packet):

| Packet | HMAC-SHA256 | Throughput of packet data |
| --- | --- | --- |
| 80-byte CNTL | 0.78 µs | 103 MB/s |
| 1,448-byte segment | 1.81 µs | 799 MB/s |
| 9,000-byte jumbo segment | 7.54 µs | 1,193 MB/s |

For comparison, 1 Gb/s is 125 MB/s. Each packet would grow by 24 bytes: an 8-byte counter and a 16-byte MAC.

libcrypto is already the estate's crypto backend: `oorexx_crypto_v0.8.3` binds it through Foreign Runtime, and its headers are on the build host. libxtp would link it directly.

## Design, if the split is accepted

### Keys

- **Long-term keys.** Each peer pair shares a 32-byte key with an 8-byte key ID. A `KeyProvider` interface supplies them, mirroring the route table:
  - first, a file: `XTP_KEY_FILE`, one line per key: peer, key ID, key, not-before and not-after;
  - later, pluggable sources: LDAP with override files (D-04), and gateway-issued temporary credentials (mode B).
- **Rotation.** Two keys may be valid at once.
- **Context keys.** For each context, HKDF-SHA256 derives two direction keys from the long-term key, salted with both ends' 16-byte nonces and labelled with the KEY, service name and route value. A key that leaks from one context is useless in another, and so is a recorded packet.

### Wire (3.4 profile, opt-in per context)

- **Open.** The FIRST's named-service descriptor sets flag `0x02` (AUTH) next to `0x01` (INTERACTIVE). Its information segment carries:
  - the key ID;
  - the initiator nonce;
  - a millisecond timestamp;
  - a MAC under an open key derived from the long-term key and that nonce.

  The responder rejects a timestamp outside ±30 s, and a nonce it has already seen within that window.
- **Accept.** The responder's FIRST carries its own nonce and a MAC under the new context key. That proves the responder holds the key and binds both nonces.
- **Every later packet** (DATA, CNTL, DIAG) ends its segment with a 24-byte tail:
  - an 8-byte per-direction packet counter;
  - a 16-byte HMAC-SHA256 (truncated) over the whole packet before the tail, header and trailer fields included.

  The receiver verifies the MAC first, then checks the counter against a 1,024-packet anti-replay window, as IPsec does.
- **Failures.** A packet that fails is dropped and counted. It is never answered, so a forger learns nothing and gets nothing reflected.
- **DIAG.** A refusal of an authenticated open is MACed with the open key. A responder without the key cannot refuse authentically, so the opener times out, and the responder's local receipt records why.

### Listener policy

- `require_authentication = false` keeps today's behaviour.
- A gateway or protected service sets it to true. Unauthenticated FIRSTs then get DIAG 17 AUTH_REQUIRED, which is already reserved.
- A key provider may also bind a key to particular services, so a temporary mode-B credential opens only its permitted service.

### Phases

1. **dev32: sessions.** Sessions are what the gateway needs. Tests:
   - forged close, END, DATA and CNTL from the peer's own address are dropped;
   - replayed packets and replayed opens are dropped;
   - a wrong key is refused;
   - a rotated key is accepted;
   - unauthenticated opens are refused at a listener that requires authentication;
   - interop with dev31 when authentication is not requested;
   - throughput.
2. **dev33: one-way messages and streams** (Queue, Storage and Memory Fabric).
3. **Later: multicast.** It needs group keys, which is a separate design.

### Not covered

- **Confidentiality.** Encrypting the data would replace the HMAC tail with an AEAD tag (ChaCha20-Poly1305 or AES-GCM) in the same position, so it can follow without a wire redesign.
- **Traffic analysis.**
- **Flooding.** The dev30 rate limits still apply.
- **A compromised long-term key.** Rotation and revocation through the provider are the remedy.

## Questions for Tom

1. **Split (recommended) or gateway only?**
2. **Where do long-term keys come from first?** Proposed: `XTP_KEY_FILE` now, LDAP with override files later, to match routes (D-04).
3. **Is confidentiality wanted now,** or authentication only, as proposed?

"Continue" will be taken as: the split, `XTP_KEY_FILE` first, authentication only, starting with dev32 sessions.
