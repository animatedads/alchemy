# IBM 4361 / OS/360 MVT ooRexx — safety10 handover

## Status

Safety10 promotes **X'14' / NR — And Register** only.  The next unsupported
boundary remains untouched:

- IA `0154D0`
- ICOUNT `511943`
- bytes `5E60C8884710`
- opcode `5E`
- PSW `00040000900154D0`

Independent Hercules/System/370 evidence identifies X'5E' as **AL — Add
Logical**.  Safety10 contains no permanent `OP5E`.

## Exact NR proof

At IA `01464C`, instruction `1420` uses R1=R2 and R2=R0 in instruction-field
terminology: destination general register 2 contained `00029960`, source general
register 0 contained `00FFFFFF`, and CC was 0.  NR therefore yields
`00029960 & 00FFFFFF = 00029960`, with CC1 because the result is nonzero.

The first unsupported attempt was atomic.  A live object-scope OP14 was then
installed.  After deliberately dirtying R5 and RAM, journal abort restored the
architectural machine while the new method remained installed.  Retrying the
same historical instruction produced R2=`00029960`, CC1, IA `01464E`.

MVT then ran another **45 instructions** before exposing X'5E'.
Evidence: `evidence/mvt_safety10_nr_journal_retry.log`.

Permanent OP14 performs a 32-bit bitwise AND, preserves the source register and
sets CC0 for zero or CC1 for nonzero.  Focused tests cover zero, nonzero,
high-bit values, same-register operands, and the exact MVT operand shape.

A fresh permanent-source replay reaches the same X'5E' frontier.
Evidence: `evidence/mvt_safety10_permanent_nr_progress.log`.

## Architecture preserved

The live archaeology model remains intentionally split:

- freeze files: durable externally verifiable whole-machine evidence/replay;
- journal points: live in-process rewind/fork/diff/retry state;
- object-scope methods: executable hypotheses outside journal rewind, surviving
  rewind and replaceable in place.

Safety10 demonstrates the advantage directly: speculative machine dirt was
rolled back without rolling back the experimental opcode implementation, so the
same costly guest state could immediately be retried.  Permanent source was
changed only after the live hypothesis passed against that exact state.

The current durable freeze codec still does not claim complete 3330 CCKD + 3215
serialization; do not conflate live journal state with a durable freeze.

## Validation

- 95 `.cls`/`.rex` sources compile
- all 44 `tests/test_*.rex` pass
- explicit supplied-real-media and real-MVT IPL tests pass
- NR native/live tests pass
- freeze/journal and live-replacement regressions pass
- permanent replay reaches X'5E' as above

SSC v0.2.2 remains explicitly pending because the exact artifact is unavailable.

## Exact next task

1. Start from sealed safety10 unchanged.
2. Treat X'5E' at `0154D0` / ICOUNT `511943` as the next genuine boundary.
3. Confirm AL/Add Logical semantics independently, including carry/CC behaviour.
4. Capture the exact effective address, storage fullword, R6 and CC at the guest
   invocation.
5. Trial live `OP5E` under journal control first; rewind/retry the same state.
6. Promote only after plausible guest progress, then seal safety11 before moving.
7. Keep the separate BCT (`46`) alias-ordering audit visible.
