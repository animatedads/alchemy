# XTP DIAG registry

**Architecture:** Tom Dyer. **Coding:** Claude (Opus 5.5), dev29 and dev30. **Written by:** Claude (Opus 5.5), as owner of the xtp component, 27 October 2026.

This file is the allocation authority for DIAG CODE and VALUE numbers in libxtp. A number not listed here is not allocated. To allocate one, send a request in the xtp component.

## Packet

Packet type 8, the XTP 4.0 code; no verified 3.4 code was available. The data segment has three parts:

- CODE, 4 bytes;
- VALUE, 4 bytes;
- an ASCII reason.

Byte order follows the header's L bit, as for every other field. The KEY carries the return bit. A sender accepts a DIAG only under the same conditions as an ACK: it must come from the route destination, carry the return bit and use the context's KEY.

## CODE

| CODE | Name | Meaning |
| --- | --- | --- |
| 1 | CONTEXT_REFUSED | The receiver will not carry this context. The sender fails the send at once. |

## VALUE, under CODE 1

| VALUE | Name | Sent by | Since |
| --- | --- | --- | --- |
| 1 | SERVICE_NOT_ADMITTED | libxtp listener: the FIRST names a service that is not in `allowed_services` | dev29 |
| 2 | OVERSIZE | libxtp listener: the stream exceeds the listener's bound | dev29 |
| 3 | MALFORMED | libxtp listener: the payload cannot be decoded | dev29 |
| 4 to 15 | unallocated, kept for libxtp | | |
| 16 | POLICY_DENIED | XTP gateway | reserved dev30 |
| 17 | AUTH_REQUIRED | XTP gateway | reserved dev30 |
| 18 | FACILITY_UNSUPPORTED | XTP gateway | reserved dev30 |
| 19 | QUOTA_EXCEEDED | XTP gateway | reserved dev30 |
| 20 | LOOP_DETECTED | XTP gateway | reserved dev30 |
| 21 | INSPECTION_DENIED | XTP gateway | reserved dev30 |
| 22 | NOT_READY | XTP gateway | reserved dev30 |
| 23 | EMERGENCY_VETO | XTP gateway | reserved dev30 |
| 24 and above | unallocated | | |

The meanings of 16 to 23 are those in `docs/XTP_GATEWAY_SPEC.md` ("Proposed gateway DIAG VALUE extension"), which ChatGPT proposed on 25 October 2026 (REQ-00000153). I have taken them as proposed, with two changes:

- **The names drop the `GATEWAY_` prefix.** A refusal reads the same to a sender whoever sends it, and a later libxtp listener refusing on quota should be able to send QUOTA_EXCEEDED without a second number.
- **They may go on the wire once a gateway sends them under its own tests. They do not have to wait for authenticated FIRST/CNTL.** The gateway spec made authentication a condition. On the merits I don't think it should be, for three reasons:
  - VALUEs 1 to 3 already go on the wire unauthenticated.
  - A forged DIAG can do nothing an on-path attacker can't already do by dropping packets.
  - Off-path forgery is stopped by the dev26 source binding and the return bit.

  Authentication remains a gate for *admitting* foreign traffic (gateway mode B). It is not a gate for *refusing* it.

## Rules for anyone who sends a DIAG

dev30 enforces these in the libxtp listener, and a gateway must follow the same rules:

1. **The reason on the wire is the VALUE name only, or empty.** Requested service names, parser messages, policy rule identifiers and generations stay in the local log or receipt.
2. **A DIAG is never larger than the packet that caused it.** If the reason doesn't fit, drop it. If even a bare DIAG (48 bytes) doesn't fit, send nothing.
3. **Rate-limit per source and in total.** The source of a refused packet is unauthenticated, and on UDP it may be forged. A peer over the limit gets silence.

## Compatibility

| Peer | Effect |
| --- | --- |
| Sender at dev29 or later | Fails fast on any CODE 1 DIAG. It names VALUEs 1 to 3; from dev30 it also names 16 to 23. Any other VALUE is reported as UNKNOWN with its number. |
| Sender at dev28 or earlier | Ignores packet type 8 and times out as before. |
