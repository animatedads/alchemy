# ooRexx X.25 v0.1-dev3 — user-space LAPB laboratory implementation

**Architecture:** Tom Dyer. **Coding and report:** ChatGPT (GPT-6), 29 October 2026. **Status:** deterministic ooRexx user-space test slice; not operationally qualified.

This version **retains the dev2** X.25 PLP, RFC1613 XOT framing and SVC transition sources unchanged, and adds `src/X25Lapb.cls`. It does not depend on Linux AF_X25, a native LAPB implementation, XTP libxtp, SocketProvider, Python, system daemon privileges or a live interface.

## New source

- `X25LapbCodec~emit(role,kind,ns,nr,payload,poll,response)` builds one single-link **modulo-8** address/control/information/FCS frame in binary. `~decode(wire,receiverRole,maxInformation)` validates HDLC FCS and DTE/DCE command/response address, control types, frame length, and I/S/U field constraints before returning typed `.X25LapbFrame`. The codec does **not** include serial flags or bit stuffing in these frame octets.
- `X25HdlcBits~encode(frame)` and `~decode(bitstream,maxOctets)` model `01111110` flag framing and five-one zero-bit stuffing in **ASCII '0'/'1' test strings**, transmitted low-bit-first per octet. This is NOT a raw serial signal/device or asynchronous HDLC byte escaping. A real adapter must declare whether it already removes flags, performs bit stuffing and/or checks FCS to avoid double processing.
- `X25LapbLink~new(role,window,t1,n2,maxInformation)` is a deterministic in-memory state machine: `start(now)`, `send(PLPbytes,now)`, `receive(wire,now)`, `tick(now)`, `disconnect(now)`, plus `drainOutgoing` and `drainDelivered`. Caller supplies **monotonic** time and transports the resulting frames. States DISCONNECTED, AWAIT_UA, CONNECTED, AWAIT_DISC, FAILED. No clocks, I/O, threads, background timers, or hidden retries.
- Window width 1..7 (default 2) under modulo-8, independent V(S), V(A), V(R); retransmits outstanding I only, and never silently replays PLP application side effects. `N2` is interpreted as **maximum transmissions including the first attempt** (documented lab profile); `T1` is a positive number of caller monotonic ticks. Invalid N(R) is rejected before acknowledgment mutation. No ACK implies downstream business commit.
- RR advances validated ACKs and releases remoteBusy; RNR blocks **new** I frames; REJ retransmits outstanding numbered frames **within the same N2 budget** (no unbounded hostile REJ amplification); out-of-order I produces REJ, duplicate I is ACKed without redelivery. SABM/UA establish and DISC/UA tear down; T1/N2 bound retries and terminal FAIL. Per-direction I data stays binary. No SocketSelector registration yet.

**Source reference:** `docs/X25_FAMILY_SPEC.md`, the existing `oorexx_x25_v0.1-dev2` implementation, ITU-T X.25 Table 5 LAPB modulo-8 control forms, and RFC1549 Appendix A reflected HDLC 16-bit FCS (`0x8408`, initial `0xFFFF`, complemented, low-byte first). The RFC provides the CRC vector, **not** a claim that PPP and LAPB have identical network behaviour. The single-link DTE command address `0x01`, DCE command address `0x03`, and reversed response addresses follow the conventional LAPB profile; multi-link addresses are intentionally refused.

## Test

```bash
# From package root. Point REXX_BIN at the exact supplied ooRexx 5.3.0 r13196 binary.
REXX_BIN=/absolute/path/to/rexx bash tests/run.sh
```

`tests/run.sh` is Bash solely for deterministic test invocation and interpreter selection; all link and regression test logic is written in ooRexx. Set `LD_LIBRARY_PATH` if using an unpacked ooRexx `.deb` rather than a system installation. Six tests use no network, no root, no native hardware, no Python and no autobuilder. Exact observed output and test command are in `docs/QUALIFICATION.md`.

## Limits / NOT_CLAIMED

This is a **basic modulo-8 single-link laboratory subset**, not full ISO 7776, a commissioned serial/LLC2/XOT carrier, or field-qualified X.25. No SABME/extended modulo-128, FRMR/DM recovery beyond minimal DM drop, selective REJ, full timer family/T3, downstream queue durability, PLL/clocking, serial/USB/sync-adapter I/O, driver-level FCS, physical octet/bit APIs, hardware backpressure, multi-link operation or real packet traffic. The test HDLC bit string API is deliberately NOT on-wire serial bytes. Layer-2 packet validation does not implement full X.25 Layer-3 facilities or D-bit delivery semantics. Do not confuse an RR ACK with end-to-end X.25 D-bit or application commit.

No new GatewaySession, cryptographic FIRST/CNTL peer identity, LDAP-backed route admission, or operational `instrumentation.mesh/0.1` bridge. Security-gated foreign ingress stays disabled pending XTP-owner work. XTP dev30 DIAG values 16–23 are reserved in the XTP owner's `docs/DIAG_REGISTRY.md`; this library does not emit XTP DIAG. The component may later become an X.25 SocketSelector family **only after** family-owner admission and live carrier qualification.

**Owned workstream:** Rasen Falcon lane `x25-gateway`. **Source continuity:** `spheres/oorexx_x25_gopher_sphere_v0.1/DEV3_LAPB.md`. **No modification** to any XTP libxtp, SocketProvider, gateway live binding, LDAP, website, mail or other agent-owned source.