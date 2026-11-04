# X.25 v0.1-dev3 — reproducible LAPB laboratory qualification record

**Architecture:** Tom Dyer. **Code, tests and evidence:** ChatGPT GPT-6, 2026-10-29.

## Runtime / source

- Supplied artifact: `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(1).deb` (unpacked with `dpkg-deb -x`, not installed as root).
- Interpreter self-identifies as **Open Object Rexx 5.3.0 r13196 Internal Test Version**, 64-bit, build date 2026-08-03.
- Test execution used the unpacked `usr/local/bin/rexx` with its `usr/local/lib` exposed as `LD_LIBRARY_PATH`.
- Working source copied from the user Library's `oorexx_x25_v0.1-dev2.zip`. The original dev2 package is unchanged. New `src/X25Lapb.cls`, `tests/test_lapb.rex`, `tests/test_lapb_negative.rex`, and the dev3 test wrapper were added separately.

## Command and result

```bash
LD_LIBRARY_PATH=/absolute/path/to/extracted/usr/local/lib \
REXX_BIN=/absolute/path/to/extracted/usr/local/bin/rexx \
bash tests/run.sh
```

```text
RUN test_packet.rex
PASS ooRexx X25Packet/XOT codec v0.1-dev2 (dev1 regression)
RUN test_vc.rex
PASS ooRexx X25VirtualCircuit v0.1-dev2 (dev1 regression)
RUN test_negative.rex
PASS ooRexx X.25 negative boundary cases
RUN test_dev2.rex
PASS test_dev2 F1 F2 F3 F4 F5 F6 and typed diagnostic/roundtrip
RUN test_lapb.rex
RUN LAPB codec/fcs/role
RUN LAPB handshake and I-frames
RUN PLP DATA over LAPB octet-to-bit-to-frame round trip
RUN LAPB backpressure and timers
RUN LAPB handshake expiry and disconnect
RUN HDLC bitstuff/unstuff with bounded flags
RUN LAPB bad-FCS rejection
PASS X25Lapb codec, FCS, roles, window, REJ, RNR, T1, N2 and disconnect
RUN test_lapb_negative.rex
RUN LAPB negative encoding and stuffing
RUN LAPB ACK and FCS corruption cannot mutate state
RUN LAPB modulo-8 wrap and bounded window
RUN LAPB repeated REJ consumes bounded N2 budget
PASS LAPB negative FCS, flags, unsupported types, ACK, wrap, no-mutation
PASS X.25 dev3 ooRexx packet, SVC and LAPB laboratory suites
```

Exit **0**; six test scripts passed; no skipped cases. Tests include the standard binary HDLC FCS vector `123456789 -> 6E90`, DTE/DCE address roles, SABM P-bit/UA, duplicate suppression, window=2 stop/reopen, RR/RNR/REJ, out-of-order recovery, T1 retransmit and N2 exhaustion, DISC/UA, modulo-8 wrap, binary X.25 PLP DATA over modelled HDLC bit stuffing, malformed stuffing/flags/FCS/invalid N(R) no-mutation, repeated malicious REJ bounded by N2. The caller injects all clock ticks; no background scheduling is involved.

## Qualification boundary

**PASS:** deterministic synthetic frame/control codec and selected link-state transitions on this interpreter. **NOT RUN:** independent ISO 7776 reference peer, HDLC serial/clock/adapter, ISO 8881 Ethernet LLC2, physical link recovery/soak, production XOT, XTP L2/L3/L4, performance under real packet loss, first-class SocketSelector registration. Neither the test scripts nor a unit-tested byte model is proof of real interoperation.