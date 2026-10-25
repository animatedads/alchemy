# X.25 v0.1-dev1 Qualification Record

Architecture: Tom Dyer. Coding and report: ChatGPT (GPT-6). 2026-10-25.

## Interpreter

Source: user-provided `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(1).deb`.
Extracted locally without system installation; Linux x86_64, ooRexx 5.3.0 r13196 (package filename/build identity; no separate runtime signature verified). `rexx` links to included `librexx.so.4` / `librexxapi.so.4`. `LD_LIBRARY_PATH` and `REXX_HOME` directed to the extracted runtime. No file was written to `/usr/local`.

## Tests actually run

- `test_packet.rex` — PASS (`rc=0`). Binary PLP, typed control, XOT split/coalesced, clean EOF.
- `test_vc.rex` — PASS (`rc=0`). Deterministic SVC CALL/RESET/CLEAR, injected T21, modulo-8 data sequences, incarnation.
- `test_negative.rex` — PASS (`rc=0`). Invalid PLP, short frames, oversized data/interrupt, malformed XOT, failed-framer permanence, incomplete EOF, policy refusal and wrong-incarnation packets.

Synthetic tests only. No peer/network/serial/LAPB, no cross-build/interpreter conformance, no independent RFC/ISO test vectors. The tests do not prove state-machine completeness or native X.25 interoperability.

## Next gates

1. Add exact X.25 operator/edition profiles and facility decoder, X.121 address block, CUD identity, SVC admission, full modulo-8 and optional modulo-128 windows.
2. Add independent ooRexx LAPB with deterministic T1/N2/FCS/HDLC and only then a serial/LLC2 adapter.
3. Attach a TCP provider only after versioned XOT socket lifecycle and facility conformance are measured against independent XOT peers.
4. Integrate separately with SocketSelector owner; do not advertise sender/listener before it is qualified.