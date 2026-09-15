# IBM 4361 / OS/360 MVT ooRexx — safety6 handover

## Status

Safety6 is a sealed archaeology checkpoint that promotes only System/370
**UNPK / Unpack, opcode X'F3'** from the safety5 frontier.  The following AF
instruction is deliberately left untouched.

## Architectural boundaries

- Freeze files remain durable, externally verifiable whole-machine evidence and
  replay artifacts.
- Journal-pointed state remains live in-process history for rewind/fork/diff/retry.
- A journal may reference a freeze checkpoint as a base but never replaces or
  redefines the freeze format.
- The guest IBM 3215 channel console remains separate from the physical IBM 4361
  operator/control console.

## F3 real-MVT proof

Historical frontier:

- IA `FF71B4`
- ICOUNT `511764`
- bytes `F332D643D67C`
- PSW `00040000B0FF71B4`
- destination EA `FFD43C`, before `F0F0F0F0`
- source EA `FFD475`, packed operand `00013C`
- CC `3`

The object-scope `OPF3` trial was installed while preserving that historical
state.  After rewind, retry produced:

- status `OK`
- IA `FF71BA`
- ICOUNT `511765`
- destination `F0F0F1C3`
- source unchanged `00013C`
- CC remained `3`

Real MVT then executed 11 additional instructions and exposed the next first
unsupported instruction:

- IA `016606`
- ICOUNT `511776`
- bytes `AF030FFF4703`
- opcode `AF`

The prior live-run evidence is transcribed, explicitly labelled as such, in
`evidence/mvt_unpk_journal_retry_transcribed.log`.

## Permanent source

`IBM370Executor.cls` now contains permanent `OPF3` and advertises F3 in the
native opcode set.  It:

- treats the rightmost packed low nibble as the sign zone;
- unpacks digits right-to-left into zoned decimal;
- uses F zones for ordinary destination bytes;
- places the packed sign in the final destination zone;
- left-pads a long destination with zoned zeroes;
- truncates high-order digits when the destination is short;
- leaves condition code unchanged;
- obeys 24-bit base/displacement addressing.

Focused regressions:

- `tests/test_cpu_unpk.rex`
- `tests/test_cpu_unpk_live_trial.rex`
- `tests/test_mvt_unpk_frontier_microstate.rex`

## Journal + live method advantage

The combination is now an intentional archaeology facility, not incidental
scaffolding.  `docs/LIVE_ARCHAEOLOGY.md` records the design in detail.

The important property is that architectural state and executable trial code
have different lifetimes.  The journal rewinds CPU/RAM/channel/clock history;
an object-scope `OPxx` method remains installed on the executor.  Therefore an
unsupported instruction can be checkpointed, trial code inserted, the machine
rewound to the exact pre-instruction state, and the same instruction retried.

Calling `installLiveMethod()` again with the same method name replaces the prior
object-scope trial in place.  `test_executor_live_method_replacement.rex` proves
both replacement and the fact that insertion/replacement survives architectural
rewind while speculative CPU/RAM effects do not.

That gives us exact-state A/B instruction archaeology and sharply reduces the
need to replay IPL for every candidate semantic.  Permanent source promotion is
therefore downstream of guest proof rather than the mechanism used to obtain
that proof.

## Validation

Runtime: supplied ooRexx 5.3.0 r13196 debug build.

- 79 `.cls`/`.rex` sources in the final checkpoint
- all 37 `tests/test_*.rex` scripts pass across chunked qualification runs
- `PASS test_real_media`
- `PASS test_real_mvt_ipl PSW=0000000000000080 CCHHR=0/0/4`
- freeze/journal separation and rewind tests remain green
- live executor insertion/replacement regression is green
- exact F3 historical microstate permanent-source replay is green

A fresh whole-trajectory permanent replay was also started on the logical-media
clone; under the supplied debug interpreter it followed the expected guest path
through IC 279332 before the execution ceiling interrupted the harness.  It did
not produce a contradictory boundary.  This is recorded transparently rather
than being represented as a completed replay.

## Probe media

The uncompressed archaeology container was recreated and reproduces the exact
safety5 probe hashes:

- original MVTRES.350 SHA-256
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`
- logical all-track digest
  `2f93094d4360bfb80923ea3dae49bbe63224a3dc6d5242059d440f4f3144e0e6`
- uncompressed probe-container SHA-256
  `3b1fce935fcc18a10408a03d124f0750a1feb823139ae418b12d68f3ed12d1a5`

The probe media remains external and is not vendored.

## SSC

The exact required `oorexx_semantic_source_control_v0.2.2` package is still not
available in the supplied roll-up.  v0.2.3 has not been silently substituted.
SSC v0.2.2 qualification therefore remains explicitly pending.

## Exact next task

1. Start from safety6 unchanged.
2. Treat AF at `016606`, ICOUNT `511776`, bytes `AF030FFF4703` as the next real
   guest boundary.
3. Use System/370 Monitor Call semantics as an oracle, but inspect the exact
   guest class/mask/code state before deciding whether this invocation should
   interrupt or act as a no-op.
4. Trial `OPAF` as an object-scope method first.
5. Rewind/retry the same historical state; only accept semantics that produce
   architecturally plausible guest progress.
6. Promote only after focused Monitor Call regressions.
7. Cut safety7 before proceeding beyond the next guest boundary.
