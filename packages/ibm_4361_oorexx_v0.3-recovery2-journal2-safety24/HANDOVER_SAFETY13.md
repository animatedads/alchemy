# IBM 4361 / OS/360 MVT ooRexx — safety13 handover

## Status

Safety13 promotes **X'D4' / NC — And Character (SS-a)** only.

The next observed boundary is deliberately **not** treated as a missing opcode:

- IA `000000`
- ICOUNT `513272`
- bytes `000000000000`
- opcode `00`
- PSW `0004000A60000000`
- executor status `UNSUPPORTED`

X'00' is an operation-exception opcode, so the next task is to determine why the
guest reached address zero and whether a proper System/370 program-interruption
path is expected.  Safety13 contains no permanent `OP00`.

## Exact NC proof

At the real-MVT frontier inherited from sealed safety12:

- IA `00660C`
- ICOUNT `513044`
- instruction bytes `D403A0A0A0A0`
- length 4 bytes
- R10=`0000B000`
- operand 1 EA=`00B0A0`, data=`00000000`
- operand 2 EA=`00B0A0`, data=`00000000`
- CC=1

This is a genuine **self-NC**.  Against the sealed safety12 executor the first
attempt is `UNSUPPORTED` atomically.  A live object-scope `OPD4` is inserted
under an instruction journal point.  Deliberately dirtied R5 and RAM are then
rolled back while the executable hypothesis remains attached.  Exact retry
produces:

- data remains `00000000`
- CC changes 1 -> 0
- IA advances to `006612`
- ICOUNT advances to `513045`

MVT then runs another 227 successful instructions; the 228th post-retry tick
exposes X'00' at IA zero / ICOUNT 513272.

Evidence: `evidence/mvt_safety13_nc_journal_retry*.log`.

## Overlap and wrap semantics

Permanent OPD4 is deliberately byte-sequential, left to right.  Each source
byte is fetched only when its corresponding destination byte is processed.
This preserves destructive overlap semantics; it does not snapshot the source
string.  Every byte address is wrapped to the 24-bit System/370 address space.

`test_cpu_nc.rex` covers:

- the exact MVT self-NC case;
- disjoint source/destination operands;
- destructive overlap where earlier stores alter later source bytes;
- a four-byte operation crossing `FFFFFF -> 000000`;
- CC0 for an all-zero result and CC1 for any nonzero result.

## Promotion equivalence

`test_cpu_nc_promotion_equivalence.rex` reconstructs the exact recorded MVT
microstate, executes the successful live OPD4 candidate, rewinds, removes the
object-scope method, and executes permanent class OPD4 from the same state.
It requires identical resulting bytes, CC and next IA.

This is the intended three-history model:

- freeze files: durable externally verifiable whole-machine evidence/replay;
- journal points: live in-process machine rewind/fork/diff/retry;
- live methods: independently insertable/replaceable/removable code hypotheses.

The latter two remain separate from the durable freeze format.

## Validation

Safety13 qualification completed under ooRexx 5.3.0 r13196 debug runtime:

- 112 `.cls`/`.rex` sources compile;
- all 54 `tests/test_*.rex` pass;
- supplied original `MVTRES.350` SHA-256 verifies;
- real-media parsing passes;
- real-MVT IPL passes at PSW `0000000000000080`, CCHHR `0/0/4`;
- NC native/live/promotion regressions pass;
- live insertion/replacement/removal regressions pass;
- freeze/journal separation passes.

A probe-only uncompressed CCKD was regenerated for archaeology acceleration.
Its 7,676 logical tracks reproduce the established logical SHA-256
`2f93094d4360bfb80923ea3dae49bbe63224a3dc6d5242059d440f4f3144e0e6`.
It is external and is not carried in the package.

Exact SSC v0.2.2 remains pending because that exact package is unavailable;
v0.2.3 is not substituted.

## Exact next task

1. Start from sealed safety13 unchanged.
2. Do **not** implement OP00.
3. Trace the final instructions/control transfer into IA zero.
4. Inspect program-interruption old/new PSW low-core locations and interrupt
   state around the transition.
5. Determine whether IA zero is intentional exception entry, a missing
   interruption mechanism, or a preceding control-flow defect.
6. Use journal/live method replacement only on the causal mechanism once
   independently identified.
7. Seal the next checkpoint before moving beyond the next proven boundary.
8. Keep the separate BCT (`46`) alias-ordering audit visible.
