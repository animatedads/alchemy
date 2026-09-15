# IBM 4361 ooRexx — Safety15 Handover

Safety15 starts from sealed safety14 and promotes only System/370 X'1E' ALR / Add Logical Register.

## Exact real-MVT archaeology

The sealed safety14 guest stops at:

- IA `01A482`
- instruction count `513307`
- instruction `1EAB` (ALR R10,R11)
- R10 `20000000`
- R11 `40000002`
- CC1

The pre-promotion executor returns `UNSUPPORTED` atomically. The already-known
lead-in is run on ordinary storage, then explicit machine/CPU/clock/storage/
device/channel state is handed in-process to journal-capable storage and
verified before experimentation.

An object-scope OP1E candidate is installed after the unsupported attempt.
Deliberate GPR/RAM dirt rewinds while the executable candidate survives.
Retry of the exact instruction produces:

- R10 `60000002`
- CC1 (no carry, nonzero)
- IA `01A484`
- instruction count `513308`

MVT then executes 7,844 further successful instructions. The next untouched
boundary is X'FF' at IA `000020`, IC `521152`, fetch window `FF04000D0001`.
Safety15 does not classify or implement X'FF'.

## Permanent ALR

Permanent OP1E implements unsigned 32-bit addition of R2 to R1, retaining the
low 32 bits in R1. Condition code matches AL:

- CC0: no carry, zero result
- CC1: no carry, nonzero result
- CC2: carry, zero result
- CC3: carry, nonzero result

Focused tests cover all four outcomes and R1==R2 aliasing.

## Promotion proof

The exact recorded MVT microstate is executed through the successful live
candidate, rewound, the object-scope OP1E is removed, and the same state is
executed through permanent class OP1E. R10, CC and next IA are required to
match exactly. This preserves the separation between reversible machine
history and independently insertable/replaceable/removable executable
hypotheses.

A test-harness rule is now explicit: helper procedures receiving emulator
objects use `use arg`, which preserves the object reference. `parse arg` is
reserved for scalar/text parsing because parsing an object argument invokes
string parsing semantics rather than preserving object identity.

## Validation

- `COMPILE PASS 120 sources`
- `RUNTIME PASS 60 tests`
- original supplied `MVTRES.350` media validation passes
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- all freeze/journal/live-method regressions remain green
- no OPFF exists

Evidence:

- `evidence/mvt_safety15_alr_journal_handoff.log`
- `evidence/safety15_compile.log`
- `evidence/safety15_full_suite.log`
- `VALIDATION_SAFETY15.txt`

## Next task

Do not implement X'FF' from the fetch window alone. First trace why the guest
reaches low-core address `000020`, inspect the immediately preceding control
transfer and relevant old/new PSW slots, and independently classify X'FF'. If
it is another architecturally undefined operation used to provoke a program
interrupt, extend the interruption classifier only after exact proof; if it is
a symptom of earlier control-flow/state error, fix the cause instead.

Project-local SSC qualification remains pinned to exact v0.2.2 unless explicitly superseded.
