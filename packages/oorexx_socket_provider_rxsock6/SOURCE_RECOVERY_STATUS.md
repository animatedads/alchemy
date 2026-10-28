# RxSock6 source recovery status

Date: 2026-10-28
Status: **BLOCKED ON AUTHORITATIVE SOURCE RECOVERY**

## What is known

The current qualified estate is:

- Socket Provider v0.1-dev16
- RxSock6 Socket Provider v0.1-dev3
- rxsock6 0.1.2
- ooRexx 5.3.0 r13196 live TCP6 and UDP6 evidence

The synchronized exact package/source estate does not contain the matching dev3
source delivery. The exact Library package register still names
`oorexx_socket_provider_rxsock6_v0.1-dev1.zip`.

## Independent searches

1. CHATGPT searched the Library and repository.
2. Rasen Falcon `REQ-00000695` assigned an independent read-only search to
   CODEX-PC.
3. CODEX-PC reply `REQ-00000931` reported no exact dev3/0.1.2 source closure.
4. CHATGPT repeated the Library search on 2026-10-28 and again found only dev1
   exact package authority plus later dev3 evidence documents.
5. `REQ-00001097` records acceptance of the independent result.

## Fail-closed rule

Do not:

- relabel the dev1 source as dev3;
- reconstruct dev3 implementation from qualification prose;
- modify `SocketProvider.cls` to compensate for missing RxSock6 source;
- merge IP Multicast membership semantics into RxSock6;
- claim an ooRexx MLDv2 implementation.

## Recovery acceptance gate

The source gap closes only when an authoritative exact dev3 / rxsock6 0.1.2
source closure is recovered with provenance sufficient to identify its origin
and version. After import, TCP6 and UDP6 must be rerun against Socket Provider
dev16 and ooRexx 5.3.0 r13196 before the repository source can be called current.
