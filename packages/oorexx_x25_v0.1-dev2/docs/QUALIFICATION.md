# X.25 v0.1-dev2 qualification — interpreter laboratory, not interop

Architecture: Tom Dyer. Coding and record: ChatGPT GPT-6. Date: 2026-10-27.

## Execution

- User-provided binary: `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(1).deb`. Locally unpacked in an isolated working directory with `dpkg-deb -x`; no system deployment or root.
- Interpreter: unpacked `usr/local/bin/rexx`; linker resolves unpacked `usr/local/lib/librexx.so.4` and `librexxapi.so.4` using explicit `LD_LIBRARY_PATH`.
- Invocation from package root: `REXX_BIN=<unpacked>/usr/local/bin/rexx bash tests/run.sh` with extracted lib path configured. `tests/run.sh` sets `REXX_PATH` to the checked package `src` directory.
- Four suites (`test_packet.rex`, `test_vc.rex`, `test_negative.rex`, `test_dev2.rex`) PASS with exit code zero; no SKIP. The three inherited suites remain unchanged except their output version label.

## Dev2 proof added

F1 A-bit CALL refusal; F2 LCN=0-only global controls and refusal of nonzero global channels; F3 circuit packets/control constructors cannot use LCN0; F4 zero, 32, 33 octet interrupts; F5 local sent/received sequences reset and new P(S)=0 after RESET_CONFIRM; F6 clear collision terminal semantics. Added binary DATA `Q/D/M`, `P(S)/P(R)`, LCN and binary payload encode/decode. Assert exact DTE RESET cause=0/diag=1 and DCE cause=5/diag=1 when invalid P(S) is found; inspectRaw assert cause/diag on oversized DATA (39) and empty INTERRUPT (38), plus local-only disposition for unqualified cases. No network I/O or fabricated acceptance.

## Explicitly NOT_QUALIFIED

No independent ITU X.25/ISO8208 or RFC1613 conformance suite, no real or simulated external X.25 peer, no device/clock/framing signal qualification, no LAPB state machine, no end-to-end deployment. Packet and VC handling remain a **limited** subset. Review dev2 code paths and check `docs/NOT_CLAIMED.md` before promoting any capability.