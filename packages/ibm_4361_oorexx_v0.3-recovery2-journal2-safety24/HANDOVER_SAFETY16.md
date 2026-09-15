# IBM 4361 ooRexx — Safety16 Handover

Safety16 starts from sealed safety15 and promotes only the independently proved
System/370 primary X'FF' operation-exception classification.  It does not add
an OPFF instruction method and does not change SVC.

## Causal trace of the safety15 FF boundary

Safety15 stopped at X'FF' at IA X'000020', instruction count 521152.  A fresh
observation-only trace on the supplied MVTRES.350 proved the immediate control
transfer was not SVC.  The final instructions include:

- IC 521150, IA 0161BC: `94F70201...`
- IC 521151, IA 0161C0: `82000200...` = LPSW from X'0200'
- IC 521152, IA 000020: `FF04000D0001` = architecturally undefined X'FF'

The LPSW loads PSW `0004000160000020`, intentionally resuming at X'20'.  Low
core at the boundary is:

- SVC old X'20': `FF04000D00014144`
- program old X'28': `0004000160000020`
- SVC new X'60': `00040000000165F0`
- program new X'68': `00040000000002CA`

Therefore the earlier hypothesis that incomplete OP0A/SVC new-PSW loading
caused this particular jump was falsified.  OP0A remains a separate audit item;
it is not changed in safety16.

## Exact real-MVT FF archaeology

The pre-promotion safety15 executor reaches:

- IA `000020`
- ICOUNT `521152`
- bytes `FF04000D0001`
- PSW `0004000160000020`

The first X'FF' attempt is `UNSUPPORTED` and atomic.  Exact CPU/storage/clock/
device/channel state is handed in-process to journal-capable storage.  An
object-scope classifier extending operation exceptions from `00` to `00|FF`
is installed; no OPFF method is installed.  Deliberately dirtied GPR/RAM state
rewinds while the executable classifier survives.

Retry of the identical X'FF' produces:

- program-old PSW `00040001E0000026`
- program-new/current PSW `00040000000002CA`
- IA `0002CA`
- instruction count `521153`

The six-byte X'FF' instruction therefore reports the expected ILC and next IA
X'26'.  MVT then executes 6,211 further successful instructions before the
next untouched boundary:

- IA `000042`
- ICOUNT `527364`
- fetch window `C4E80C000000`
- opcode `C4`

Safety16 does not classify or implement C4.

## Permanent implementation

`architecturalOperationException()` remains an explicit positive allow-list and
now recognizes only the independently proved primary opcodes X'00' and X'FF'.
`programInterruptOperation()` remains the safety14-qualified System/370 BC-mode
operation-exception delivery path.  Unknown emulator coverage gaps continue to
return `UNSUPPORTED` atomically.

No synthetic OP00 or OPFF methods exist.

## Promotion proof

Focused tests cover the exact FF microstate.  The successful live classifier
is executed, the journal restores the identical machine state, the object
classifier/interrupt overrides are removed, and permanent class dispatch is
executed.  Program-old PSW, complete program-new PSW, and instruction count
must match exactly.

## Validation

- `COMPILE PASS 125 sources`
- `RUNTIME PASS 63 tests`
- supplied original MVTRES.350 SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`
- real media test passes
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- all freeze/journal/live-method regressions remain green
- no OPFF exists
- no OPC4 exists

Evidence:

- `evidence/mvt_safety16_ff_trace.log`
- `evidence/mvt_safety16_ff_program_interrupt_journal_handoff.log`
- `evidence/safety16_compile.log`
- `evidence/safety16_full_suite.log`

## Next task

Start from sealed safety16.  Independently classify primary X'C4' for the
System/370 architecture before changing code.  If it is architecturally
undefined, trial it through the existing operation-exception classifier at the
exact `000042 / 527364` state; if it is an assigned instruction or a symptom of
bad control flow, investigate the causal instruction instead.  Do not invent
OPC4 from the fetch bytes alone.

Project-local SSC qualification remains pinned to exact v0.2.2 unless
explicitly superseded.
