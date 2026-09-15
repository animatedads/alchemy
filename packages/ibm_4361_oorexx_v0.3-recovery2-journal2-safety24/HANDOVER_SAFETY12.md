# IBM 4361 / OS/360 MVT ooRexx — safety12 handover

## Status

Safety12 promotes **X'56' / O — Or (RX)** only.  The next unsupported boundary
is deliberately untouched:

- IA `00660C`
- ICOUNT `513044`
- bytes `D403A0A0A0A0`
- opcode `D4`
- independent Hercules/System/370 evidence identifies X'D4' as **NC — And Character**

Safety12 contains no permanent `OPD4`.

## Exact O proof

At the real MVT frontier:

- IA `0146FC`
- ICOUNT `512240`
- instruction `561C0004`
- R1=`00035EC8`
- X2=R12=`00035ED8`
- B2=0
- effective address `035EDC`
- storage fullword=`FC000000`
- CC=0

Sealed safety11 reports the first attempt as `UNSUPPORTED` atomically.  A live
object-scope `OP56` was installed under an active instruction journal point.
Deliberately changed R5 and RAM were then rolled back while the executable
candidate remained attached.  Exact retry produced:

- R1=`FC035EC8`
- CC=1
- IA `014700`
- storage operand unchanged

MVT then executed another **803 instructions** before exposing X'D4' at the
frontier above.  Evidence: `evidence/mvt_safety12_o_journal_retry.log`.

Permanent OP56 performs a 32-bit bitwise OR of the storage operand into R1,
leaves storage unchanged, and sets CC0 for a zero result or CC1 for nonzero.

## Promotion equivalence

`test_cpu_o_promotion_equivalence.rex` reconstructs the exact recorded MVT
frontier microstate, executes the same successful live OP56 source, rewinds,
removes the object-scope method, and executes permanent class OP56.  It requires
identical R1, CC, next IA and storage.  This uses the safety11
insert/replace/remove architecture exactly as intended: machine history and code
hypothesis history remain independently reversible.

## Freeze / journal / code-hypothesis boundary

- freeze files: durable externally verifiable whole-machine evidence/replay;
- journal points: live in-process machine rewind/fork/diff/retry;
- object-scope methods: insertable/replaceable/removable executable hypotheses.

Do not fold journal or live-method state into the durable freeze format merely
to accelerate archaeology.

## Validation

Safety12 qualification completed:

- 107 `.cls`/`.rex` sources compile
- all 51 `tests/test_*.rex` pass
- supplied real media and real-MVT IPL tests pass
- O native/live/promotion regressions pass
- live insertion/replacement/removal regressions pass
- freeze/journal separation passes

Exact SSC v0.2.2 remains pending because that exact package is unavailable;
v0.2.3 is not substituted.

## Exact next task

1. Start from sealed safety12 unchanged.
2. Treat X'D4' at `00660C` / ICOUNT `513044` as the next genuine boundary.
3. Confirm NC / And Character SS-a semantics independently, especially length,
   overlap, boundary and condition-code rules.
4. Capture the exact two storage operands and length at the guest invocation.
5. Trial live OPD4 under journal control first and retry the same state.
6. Use removal-based candidate->permanent equivalence before promotion.
7. Seal safety13 before moving again.
8. Keep the separate BCT (`46`) alias-ordering audit visible.
