# X.25 / LAPB dev3 continuity — Gopher sphere note

**Architecture:** Tom Dyer. **Coding and sphere update:** ChatGPT GPT-6, 2026-10-29. **Lane:** `x25-gateway` (CHATGPT). **State:** source + deterministic lab tests, NOT field qualified.

## Exact new source paths

- `packages/oorexx_x25_v0.1-dev3/src/X25Lapb.cls`: `.X25LapbCodec`, `.X25LapbFrame`, `.X25LapbOutstanding`, `.X25LapbLink`, `.X25HdlcBits`.
- `packages/oorexx_x25_v0.1-dev3/tests/test_lapb.rex` and `test_lapb_negative.rex`: six-script suite alongside unchanged dev2 tests.
- `packages/oorexx_x25_v0.1-dev3/README.md` and `docs/QUALIFICATION.md`: exact interpreter/runtime claims and limitations.

A serial adapter may deliver de-stuffed frame octets with FCS to the codec, or supply an explicit bitstream so the `X25HdlcBits` model can be tested. Do not apply FCS or bitstuffing twice if the hardware does it. No socket or serial driver is linked. LAPB ACK is link-level only. Modulo-8 and configured role/window/T1/N2 are mandatory for this subset. Byte-order for CRC follows little-endian FCS convention. Outgoing full frames are queued as binary; application I/O must be owned externally and verified. The ASCII bitstream helper is a test representation, not a serial port driver.

## Correct integration order

1. Keep `X25VirtualCircuit` (packet/LCN truth) separate from `X25LapbLink` (link-level V(S)/V(A)/V(R) truth). The same symbols refer to independent sequence spaces.
2. Add hardware/framing adapter qualification before any live release; ownership of interface, DTE/DCE, MTU, FCS, hot-unplug and clocks must be proven.
3. Qualify real RFC1613 TCP/1998 XOT independently; it carries PLP, not LAPB frames.
4. Revisit PLP facilities, modulo-128 and PAD under explicit edition/operator profiles. No unauthenticated mode-B XTP foreign socket ingress.
5. XTP dev30 DIAG registry `packages/oorexx_xtp_v0.1-dev30/docs/DIAG_REGISTRY.md` (VALUES 16–23) belongs to XTP owner Claude. Gateway response implementation and authentication gates remain separate work.

## Release and evidence

Interpreter: user-supplied ooRexx 5.3.0 r13196. Six tests PASS with no network, no root and no autobuilder. The code was not load-tested against real X.25 carriers. `docs/NOT_CLAIMED.md` must remain authoritative for unimplemented gateway/physical/LDAP/HTTPS/mesh. This sphere records ownership and continuation, not qualification or new authority.

**Adversarial correction:** A repeated peer REJ can trigger repeated I retransmissions; dev3 now charges those against N2 exactly like T1, and fails the link closed at exhaustion. See `test_lapb_negative.rex`.