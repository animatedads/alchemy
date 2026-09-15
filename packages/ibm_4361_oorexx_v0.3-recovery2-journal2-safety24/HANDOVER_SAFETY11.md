# IBM 4361 / OS/360 MVT ooRexx — safety11 handover

## Status

Safety11 promotes **X'5E' / AL — Add Logical** only.  It also strengthens the
live-archaeology executor seam with explicit object-scope method removal so a
successful live candidate can be withdrawn and the permanent class method can
be exercised from the same journal-restored machine state.

The next unsupported boundary is deliberately untouched:

- IA `0146FC`
- ICOUNT `512240`
- bytes `561C0004501C`
- opcode `56`
- independent Hercules/System/370 evidence identifies X'56' as **O — Or (RX)**

Safety11 contains no permanent `OP56`.

## Exact AL proof

At the real MVT frontier:

- IA `0154D0`
- ICOUNT `511943`
- instruction `5E60C888`
- R6=`80016A60`
- effective address `015D50`
- storage fullword=`40000000`
- CC=1

Sealed safety10 correctly reports the first attempt as `UNSUPPORTED` without
advancing IA or instruction count.  Under an active instruction journal point,
a live object-scope `OP5E` was installed.  R5 and RAM were deliberately dirtied;
abort restored the exact machine state while the new executable method remained
installed.  Retrying the same historical AL produced:

- R6=`C0016A60`
- CC=1 (no carry, nonzero)
- IA `0154D4`
- storage operand unchanged

MVT then executed another **296 instructions** before exposing X'56' at the
frontier above.  Evidence: `evidence/mvt_safety11_al_journal_retry.log`.

Permanent `OP5E` implements unsigned/logical 32-bit addition and the four
architectural carry/zero condition-code outcomes:

- CC0: no carry, zero result
- CC1: no carry, nonzero result
- CC2: carry, zero result
- CC3: carry, nonzero result

## Insert / replace / remove: independent executable history

The executor now exposes both:

- `installLiveMethod(name, source)` — insert or replace an object-scope method;
- `removeLiveMethod(name)` — withdraw that object-scope method.

These operations are intentionally **not journalled machine state**.  Journal
rewind restores CPU/RAM/channel/clock/machine consequences but does not undo
which experimental code is currently attached to the executor object.

This gives the archaeology loop a complete reversible code lifecycle:

`insert candidate -> rewind -> replace candidate -> rewind -> remove candidate -> rewind -> permanent class method`

`test_executor_live_method_removal.rex` proves that removal survives machine
rewind while deliberately dirtied GPR/RAM state does not.

`test_cpu_al_promotion_equivalence.rex` then uses the recorded AL frontier
microstate to run the successful live candidate, rewind that exact state,
withdraw the object override, and execute permanent `OP5E`.  Live and permanent
paths produce identical R6, CC, next IA, and unchanged storage.  This provides a
direct candidate-to-permanent promotion proof without requiring another full
IPL solely to compare the two implementations.

A whole-guest replay remains valuable corroboration where affordable, but it is
no longer the only way to prove that promoted class code equals the code already
accepted by the guest at the exact frontier.

## Freeze versus journal remains separate

- **Freeze files** remain durable, externally verifiable whole-machine
  evidence/replay artifacts.
- **Journal points** remain live in-process history for rewind/fork/diff/retry.
- **Object-scope methods** remain executable hypotheses with an independent
  lifetime from both.

The present durable freeze codec still does not claim complete 3330 CCKD + 3215
serialization; do not redefine freeze files to carry live journal or method
state merely to shorten the archaeology loop.

## Validation

Safety11 qualification completed:

- 102 `.cls`/`.rex` sources compile
- all 48 `tests/test_*.rex` pass
- explicit supplied-real-media and real-MVT IPL tests pass
- AL native/live/promotion regressions pass
- freeze/journal separation passes
- live method insertion/replacement/removal passes

Exact SSC v0.2.2 remains pending because the exact package is still unavailable;
v0.2.3 is not substituted.

## Exact next task

1. Start from sealed safety11 unchanged.
2. Treat X'56' at `0146FC` / ICOUNT `512240` as the next genuine boundary.
3. Confirm O/Or semantics independently.
4. Capture the exact R1, effective address, storage fullword and CC at the guest
   invocation.
5. Trial object-scope `OP56` under journal control and retry the same state.
6. Use remove-live-method promotion equivalence before permanent promotion.
7. Seal safety12 before moving to the following boundary.
8. Keep the separate BCT (`46`) alias-ordering audit visible.
