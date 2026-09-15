# IBM 4361 / OS/360 MVT ooRexx — safety8 handover

## Status

Safety8 repairs a System/370 **BAL (X'45') RX effective-address sequencing
bug** exposed while investigating safety7's apparent `B0` frontier.  `B0` was
not a missing instruction at all: it was data reached because BAL wrote its
link register before calculating an effective address which aliased that same
register.

The next genuine unsupported CPU instruction is deliberately left untouched:
**X'13' / LCR at IA `014FCA`, ICOUNT `511869`**.

## Architectural boundaries

- Freeze files remain durable, externally verifiable whole-machine evidence and
  replay artifacts.
- Journal-pointed state remains live in-process history for rewind/fork/diff/retry.
- Object-scope live methods are executable hypotheses and intentionally survive
  architectural rewind.
- A journal never replaces or redefines the durable freeze format.
- The guest-visible IBM 3215 channel console remains separate from the physical
  IBM 4361 operator/control console.

`docs/LIVE_ARCHAEOLOGY.md` expands these boundaries and now includes BAL as a
worked causal-debugging example.

## Why the safety7 B0 frontier was false

Safety7 stopped at:

- IA `018A72`
- ICOUNT `511782`
- bytes `B05458F0B094`
- apparent opcode `B0`

Independent Hercules opcode tables mark primary `B0` undefined for System/370,
while `AF` is MC and `B1` is LRA.  We therefore did **not** invent `OPB0`.

A backwards trace showed the immediately preceding control transfer:

- IA `018984`
- instruction `45A0A0EA`
- BAL R10, with R10 also B2
- pre-instruction R10 `00018980`

The architectural RX target is therefore:

`00018980 + 00000EA = 00018A6A`

The old executor implemented OP45 by writing the link to R1 first and only then
calling `eaRX()`.  Because R1 and B2 were both R10, `eaRX()` saw link value
`B0018988` instead of old R10 `00018980`, yielding low-24-bit target `018A72` —
exactly eight bytes too far.

BALR (`05`) already captured its branch target before writing the link register,
which helped isolate this as an OP45 ordering defect rather than a general
branch-framework failure.

## Exact journal + live-method proof

Before permanent source was changed, the real MVT machine was run to the exact
pre-BAL state.  Under an instruction journal point:

1. old permanent OP45 executed and reproduced target `018A72`;
2. abort restored IA `018984`, ICOUNT `511781`, R10 `00018980`;
3. a corrected object-scope `OP45` was inserted which calculates EA before
   writing R1;
4. a GPR and RAM were deliberately dirtied and the instruction was aborted;
5. architectural dirt was rewound while the inserted OP45 remained installed;
6. the exact BAL was retried and produced target `018A6A`, link `B0018988`;
7. real MVT then executed 87 further instructions before the next unsupported
   boundary.

Evidence: `evidence/mvt_safety8_bal_journal_retry.log`.

The probe's final convenience-report line attempted to call a nonexistent 3215
`outputRecords` method after the next boundary had already been logged.  That is
retained as a transparent harness-only reporting error; it does not affect the
recorded BAL rewind/retry or next-boundary evidence.

A focused microstate trial also proves the same rewind/live-insertion lifetime
contract without the long guest lead-in.

## Permanent repair

`IBM370Executor.cls` OP45 now:

1. decodes RX fields;
2. calculates the branch target using the pre-instruction GPR state;
3. forms the BC-mode BAL link word from ILC/CC/program mask and IA+4;
4. writes R1;
5. returns the already-calculated target.

Focused regression `tests/test_cpu_bal_aliasing.rex` covers both:

- R1 == B2, using the exact MVT shape; and
- R1 == X2.

It fails against safety7 and passes after the safety8 promotion.

A nearby audit item remains deliberately separate: `OP46`/BCT also mutates R1
before a later conditional EA calculation.  That alias case has not been folded
into this repair and should receive its own focused architectural qualification.

## Fresh permanent-source real-MVT replay

A fresh replay from IPL using the logical-equivalent uncompressed archaeology
media follows the historical path, takes the corrected BAL target `018A6A`, and
continues to the same boundary observed by the live trial:

- IA `014FCA`
- ICOUNT `511869`
- bytes `137747408E4A`
- opcode `13`
- PSW `0004000050014FCA`

This is **87 instructions beyond** the old safety7 B0 stop.  The low-core program
old PSW remains zero, confirming that the repair did not merely route the false
B0 through an operation-exception handler; B0 is no longer fetched.

Evidence: `evidence/mvt_safety8_permanent_bal_progress.log`.

Independent Hercules source identifies X'13' as **LCR — Load Complement
Register**.  It is not implemented in safety8.

## Why journalable state + live replacement matter

Safety8 demonstrates an advantage beyond unsupported-opcode prototyping: the
mechanism can move the experiment **back to the causal predecessor** when the
visible frontier is only a symptom.

- Machine-state hypotheses and code hypotheses have independent lifetimes.
- A failed BAL can be executed, rewound, then retried with altered code against
  the same PSW/register/RAM/device state.
- Installed/replaced methods survive rewind while speculative architectural
  effects do not.
- Competing implementations can be A/B tested without repeated IPL.
- The guest itself supplies acceptance evidence by progressing from the exact
  state, instead of a diagnostic merely disappearing.
- Permanent source remains downstream of live proof.

This is particularly valuable when reaching the frontier costs more than half a
million interpreted guest instructions.

## Freeze coverage note

The conceptual freeze/journal separation remains intact, but the current
`IBM4361State` v2 durable freeze codec only has explicit device serialization
for its supported IPL-memory device path.  It fails closed for the real MVT
3330 CCKD + 3215 attachment combination.  Consequently safety8 does **not**
pretend the live BAL point is already a durable whole-machine freeze.

Extending durable 3330/3215 freeze codecs is a worthwhile independent task.  It
must preserve the current separation: durable device evidence belongs in the
freeze schema; live journal internals do not.

## Validation

Runtime: supplied ooRexx 5.3.0 r13196 debug build.

- `87` `.cls`/`.rex` sources compile
- all `40` `tests/test_*.rex` runtime scripts pass
- explicit `test_real_media.rex` against supplied `MVTRES.350`: PASS
- explicit `test_real_mvt_ipl.rex`: PASS, PSW `0000000000000080`, CCHHR `0/0/4`
- focused BAL alias regression: PASS
- executor live-method replacement regression: PASS
- MC regression: PASS
- fresh permanent real-MVT replay reaches X'13' as above
- explicit real-media tests are run by the full suite when `MVTRES_350` is set

## SSC

The exact requested `oorexx_semantic_source_control_v0.2.2` artifact remains
unavailable.  v0.2.3 is not silently substituted.  SSC v0.2.2 qualification is
therefore still explicitly pending.

## Exact next task

1. Start from sealed safety8 unchanged.
2. Treat X'13' at IA `014FCA`, ICOUNT `511869`, bytes `137747408E4A` as the next
   genuine CPU boundary.
3. Confirm LCR semantics from an independent System/370 source/oracle.
4. Capture R1/R2, CC/program mask and overflow-mask state at the exact guest
   invocation.
5. Trial live `OP13` first under an instruction journal point.
6. Exercise normal, zero and `80000000` fixed-point-overflow behaviour in a
   focused regression; do not silently ignore the fixed-point overflow program
   mask path.
7. Rewind/retry the exact MVT state and require plausible forward progress.
8. Promote only the proven scope, run the full suite and fresh replay, then cut
   safety9 before moving again.
