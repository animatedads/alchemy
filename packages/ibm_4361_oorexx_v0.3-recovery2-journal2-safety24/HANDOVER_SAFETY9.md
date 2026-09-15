# IBM 4361 / OS/360 MVT ooRexx — safety9 handover

## Status

Safety9 promotes **System/370 X'13' / LCR — Load Complement Register** only.
The permanent implementation is backed by focused instruction tests, a live
object-method trial, an exact real-MVT journal rewind/retry at the historical
frontier, and a fresh permanent-source replay.

The next unsupported CPU boundary is deliberately untouched:

- IA `01464C`
- ICOUNT `511897`
- bytes `1420506032CE`
- opcode `14`
- PSW `000400008001464C`

Independent System/370/Hercules evidence identifies X'14' as **NR — And
Register**.  Safety9 contains no permanent `OP14`.

## Architectural boundaries preserved

- **Freeze files** remain durable, externally verifiable whole-machine
  evidence/replay artifacts.
- **Journal-pointed state** remains live in-process history for
  rewind/fork/diff/retry.
- **Object-scope live methods** remain executable hypotheses outside the
  journalled machine state.  They intentionally survive architectural rewind
  and can be replaced in place.
- A journal may reference or start from durable evidence, but does not replace
  or redefine the freeze format.
- The guest-visible IBM 3215 channel console remains separate from the physical
  IBM 4361 operator/control console.

The current durable freeze codec still intentionally fails closed for the real
MVT 3330 CCKD + 3215 combination; do not describe a live journal point as a
whole-machine durable freeze until explicit device codecs exist.

## LCR semantics promoted

`OP13` decodes the RR operands and treats R2 as a signed 32-bit integer.

- zero -> zero, CC0
- positive -> negative, CC1
- negative -> positive, CC2
- X'80000000' -> X'80000000', CC3 fixed-point overflow

For X'80000000' with the fixed-point-overflow program mask enabled, safety9
**fails closed** because the required program-interruption path has not yet been
qualified in this emulator.  It does not silently continue and does not invent
low-core interruption behaviour.

Focused regression: `tests/test_cpu_lcr.rex`.
Live-method regression: `tests/test_cpu_lcr_live_trial.rex`.

## Exact real-MVT journal + live-method proof

At the safety8 frontier the guest state was:

- IA `014FCA`
- ICOUNT `511869`
- instruction `1377`
- R7 `FFFFFFF4` (-12)
- CC `1`
- program mask `0`

The unsupported attempt returned without advancing architectural state.  An
object-scope `OP13` candidate was installed while the frontier remained under
journal control.  Rewind restored the exact guest invocation while the newly
installed method remained attached to the executor.  Retrying that *same*
instruction produced:

- R7 `0000000C` (+12)
- CC `2`
- IA `014FCC`
- ICOUNT `511870`

MVT then executed another **27 instructions** before exposing X'14' at
`01464C` / ICOUNT `511897`.

Evidence: `evidence/mvt_safety9_lcr_journal_retry.log`.

## Permanent-source replay

After promoting only the proven LCR behaviour, a fresh real-MVT replay follows
the same path and reaches the same next boundary:

- IA `01464C`
- ICOUNT `511897`
- bytes `1420506032CE`
- opcode `14`

Evidence: `evidence/mvt_safety9_permanent_lcr_progress.log`.

This satisfies the project acceptance rule: the old diagnostic did not merely
disappear; the same historical path made architecturally plausible forward
progress to a new deterministic boundary.

## Why the journal/live-method design keeps paying off

Safety9 is another concrete example of treating **machine state** and
**executable hypotheses** as two separately managed timelines.

The journal owns the expensive historical machine state: PSW, registers,
memory and supported device/runtime state can be rewound to the exact
invocation.  The executor's object-scope method table is deliberately outside
that rewind, so a proposed instruction implementation can be inserted or
replaced without destroying the guest checkpoint.

That gives several practical advantages:

1. **Exact-state retry rather than approximate reproduction.**  The LCR
   candidate was judged against the same R7/CC/PSW state which exposed the
   unsupported instruction.
2. **No permanent source contamination during discovery.**  A candidate can be
   discarded or replaced while the permanent executor remains unchanged.
3. **A/B semantics on one historical state.**  Close alternatives can be
   substituted under the same `OPxx` name and compared after rewind.
4. **Failure can remain informative.**  Unqualified branches such as masked
   LCR fixed-point-overflow can fail closed while ordinary guest behaviour is
   still proved and promoted.
5. **Expensive IPL paths cease to be the unit of experimentation.**  Reaching
   this frontier costs more than half a million guest instructions; once the
   journal point exists, semantic iteration occurs at the frontier itself.
6. **Causal debugging remains possible.**  As safety8's BAL repair showed, the
   journal can be moved to a predecessor when the visible unsupported opcode is
   only a symptom, while live replacement tests a causal repair against the
   same machine history.

Freeze files complement rather than compete with this.  A future durable
3330/3215 freeze codec will make these expensive archaeology points portable
and externally replayable; the journal will remain the fast local mechanism
for branching and retrying hypotheses from such a base.

## Validation

Runtime: supplied ooRexx 5.3.0 r13196 debug build.

- `91` `.cls`/`.rex` sources compile
- all `42` `tests/test_*.rex` scripts pass
- supplied `MVTRES.350` media test passes
- real MVT IPL passes: PSW `0000000000000080`, CCHHR `0/0/4`
- LCR native/live regressions pass
- freeze/journal separation regressions pass
- live insertion/replacement regressions pass
- permanent real-MVT replay reaches X'14' as above

The long suite crossed a 120-second outer command limit after the first 39 tests
had passed; the last three tests were immediately completed under the same
environment and also passed.  The combined evidence is retained in
`evidence/safety9_full_suite.log`.

## SSC

The exact requested `oorexx_semantic_source_control_v0.2.2` artifact remains
unavailable.  `v0.2.3` is not silently substituted.  SSC v0.2.2 qualification
therefore remains explicitly pending.

## Exact next task

1. Start from sealed safety9 unchanged.
2. Treat X'14' at IA `01464C`, ICOUNT `511897`, bytes `1420506032CE` as the next
   genuine CPU boundary.
3. Confirm NR semantics independently.
4. Capture R1/R2 values and CC at the exact invocation.
5. Trial object-scope `OP14` under an instruction journal point first.
6. Rewind/retry the identical guest state and require plausible forward
   progress.
7. Promote only the proven NR scope, run the full focused/general suite and a
   permanent replay, then cut safety10 before moving to the following boundary.
8. Keep the separate BCT (`46`) alias-ordering audit item visible; do not fold
   it into unrelated instruction promotions.
