# IBM 4361 / OS/360 MVT ooRexx — safety7 handover

## Status

Safety7 is a sealed archaeology checkpoint that promotes the **masked/no-op
subset of System/370 MONITOR CALL, opcode X'AF'** exposed by the safety6 real-MVT
frontier.  The next B0 instruction is deliberately left untouched.

This is intentionally narrower than claiming complete MONITOR CALL support.
The monitor-event interruption path for an enabled class is still fail-closed.

## Architectural boundaries

- Freeze files remain durable, externally verifiable whole-machine evidence and
  replay artifacts.
- Journal-pointed state remains live in-process history for rewind/fork/diff/retry.
- A journal may reference a freeze checkpoint as a base but never replaces or
  redefines the freeze format.
- Object-scope live instruction methods are executable archaeology overlays,
  not journalled machine state.
- The guest IBM 3215 channel console remains separate from the physical IBM 4361
  operator/control console.

## AF real-MVT boundary

Inherited real-MVT frontier from the successful F3/UNPK journal trial:

- IA `016606`
- ICOUNT `511776`
- bytes `AF030FFF4703`
- opcode `AF`

The AF instruction itself is `AF030FFF`:

- bits 8-11 are zero, satisfying MONITOR CALL's reserved-field requirement;
- monitor class is 3;
- B1=0, D1=FFF, hence monitor code `000FFF`;
- CR8 is reset to zero by `IBM370CPU` and no implemented instruction on the
  executed path writes a control register, so class 3 is masked off.

IBM System/370 Principles of Operation defines this exact case as a no-operation
when the corresponding CR8 monitor-mask bit is zero, with condition code
unchanged.  If the bit is one, a monitor-event program interruption occurs.

## Journal + live-method trial

Before AF was promoted into permanent source, the executor returned UNSUPPORTED
at the boundary without changing IA or instruction count.

A live `OPAF` Candidate A was inserted while an instruction journal checkpoint
was active.  The experiment deliberately modified CR8, a GPR, and RAM after the
checkpoint, then aborted the instruction.  The journal restored all those
architectural effects while the object-scope `OPAF` method remained installed.
The same AF invocation could therefore be retried using the new method but the
old machine state.

Candidate A handled only the reset-zero CR8 case.  It was then replaced in place
under the same `OPAF` name by Candidate B, which decoded the class and selected
the corresponding CR8 bit.  The invocation state was rewound again and Candidate
B superseded A on retry.  When class 3 was deliberately enabled, Candidate B
failed closed rather than inventing monitor-event interruption state.

Pre-promotion evidence is recorded in
`evidence/mvt_mc_live_trial_pre_promotion.log`.  The post-promotion regression
`tests/test_mvt_mc_live_journal_trial.rex` repeats the same journal/insertion/
replacement lifetime properties over the permanent executor.

## Why these facilities matter

`docs/LIVE_ARCHAEOLOGY.md` now includes AF as a worked example.  The key design
advantage is that **machine hypotheses and code hypotheses have independent
lifetimes**:

- journal rewind can remove speculative CPU/RAM/channel/clock consequences;
- the live OPxx candidate survives that rewind;
- replacing the same object method changes the code hypothesis without moving
  the historical machine point;
- candidate A and candidate B can therefore be compared against the same
  invocation rather than merely similar reboots;
- permanent source is downstream of guest proof instead of being the mechanism
  used to obtain proof;
- expensive IPL/loader replay is avoided for each semantic refinement whenever
  a supported journal point is available;
- unproven branches can remain fail-closed rather than becoming speculative
  emulator behaviour.

This complements, rather than replaces, freeze files.  Freeze is durable whole-
machine evidence; journals are cheap live history; live methods are temporary
executable hypotheses.

## Permanent source

`IBM370Executor.cls` now advertises AF and contains permanent `OPAF` with this
scope:

1. decode SI immediate/base/displacement fields;
2. reject nonzero bits 8-11 as an architectural specification boundary;
3. use bits 12-15 as monitor class 0..15;
4. map classes 0..15 to CR8 bits 16..31 respectively;
5. if the selected mask bit is zero, return IA+4 without changing CC;
6. if the selected mask bit is one, fail closed because monitor-event
   interruption sequencing has not yet been promoted.

Focused regressions:

- `tests/test_cpu_mc.rex`
- `tests/test_mvt_mc_live_journal_trial.rex`
- `tests/test_executor_live_method_replacement.rex`

## Fresh permanent-source real-MVT replay

A fresh replay from IPL using the logical-equivalent uncompressed archaeology
media completed under the supplied ooRexx 5.3.0 r13196 debug runtime.

It followed the same earlier path, including:

- IC 379332 at IA `FF7062`
- IC 479332 at IA `FF70AE`
- IC 504332 at IA `FF70A8`

It passed the old AF boundary and stopped at the next first unsupported
instruction:

- IA `018A72`
- ICOUNT `511782`
- bytes `B05458F0B094`
- opcode `B0`
- PSW `00040000B0018A72`
- 3215 output records: `0`

Thus the AF promotion produces concrete guest progress rather than merely
removing a diagnostic.  From IC 511776 to the next unsupported state, AF plus
five following instructions complete before B0 is encountered.

Raw replay evidence is retained as `evidence/mvt_safety7_frontier.log`.

## Validation

Runtime: supplied ooRexx 5.3.0 r13196 debug build.

- `83` `.cls`/`.rex` source files compile
- all `39` `tests/test_*.rex` scripts pass/expected-skip in ordinary suite mode
- explicit `test_real_media.rex` against supplied `MVTRES.350`: PASS
- explicit `test_real_mvt_ipl.rex` against supplied `MVTRES.350`: PASS,
  PSW `0000000000000080`, CCHHR `0/0/4`
- freeze/journal separation and rewind regressions remain green
- live executor insertion/replacement regressions remain green
- fresh permanent-source real-MVT replay reaches B0 as described above

Logs are retained under `evidence/`.

## SSC

The exact required `oorexx_semantic_source_control_v0.2.2` package is still not
available in the supplied roll-up or recovered files.  v0.2.3 has not been
silently substituted.  SSC v0.2.2 qualification therefore remains explicitly
pending.

## Exact next task

1. Start from safety7 unchanged.
2. Treat B0 at IA `018A72`, ICOUNT `511782`, bytes `B05458F0B094` as the next
   real guest boundary.
3. Identify B0 from an independent System/370 source/oracle; do not infer its
   semantics merely from the opcode value.
4. Capture the exact operand/register/control state required by that instruction.
5. Trial `OPB0` as an object-scope method first.
6. Use a journal point to rewind/retry the same historical state; replace the
   live method in place if competing semantic interpretations need comparison.
7. Promote only after focused regressions and architecturally plausible guest
   progress.
8. Cut safety8 before moving to the following boundary.
