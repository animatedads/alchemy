# IBM 4361 ooRexx — Safety17 Handover

Safety17 starts from sealed safety16 and promotes only the independently proved
System/370 primary X'C4' operation-exception classification.  It does not add
an OPC4 instruction method.

## Exact real-MVT archaeology

Sealed safety16 reaches:

- IA `000042`
- ICOUNT `527364`
- bytes `C4E80C000000`
- PSW `0004000160000042`

System/370 architecture evidence treats this primary opcode as unassigned on
the target architecture; later architectures reuse portions of the C4 opcode
space, so safety17's classification is intentionally System/370-specific.

The first C4 attempt under the safety16 classifier is `UNSUPPORTED` and atomic.
Exact machine/CPU/clock/storage/device/channel state is handed in-process to
journal-capable storage.  A live classifier extending the positive allow-list
from `00|FF` to `00|FF|C4` survives journal rewind while deliberately dirtied
GPR/RAM state is restored.

Retry of the identical C4 state produces:

- program-old PSW `00040001E0000048`
- complete program-new/current PSW `00040000000002CA`
- IA `0002CA`
- instruction count `527365`

No OPC4 method is installed.

MVT then executes 1,727 additional successful instructions and stops at the
next untouched boundary:

- IA `000050`
- ICOUNT `529092`
- bytes `62E050000001`
- opcode `62`

Safety17 does not classify or implement X'62'.

## Permanent implementation

`architecturalOperationException()` remains a narrow positive allow-list and
now recognizes only the independently proved primary operation-exception
opcodes `00`, `FF`, and System/370 `C4`.  All other emulator coverage gaps
remain atomic `UNSUPPORTED` archaeology boundaries.

`programInterruptOperation()` remains the separately qualified BC-mode
operation-exception delivery path.  No OP00, OPFF, or OPC4 methods exist.

## Promotion proof

The exact C4 microstate is executed through the successful live classifier,
rewound, the object-scope classifier/interrupt overrides are removed, and the
same state is executed through permanent class dispatch.  Program-old PSW,
program-new PSW, and instruction count are required to match exactly.

## Validation

- `COMPILE PASS 129 sources`
- `RUNTIME PASS 66 tests`
- original supplied MVTRES.350 SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`
- real media validation passes
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- all freeze/journal/live-method regressions remain green
- no OPC4 exists
- no OP62 exists

Evidence:

- `evidence/mvt_safety17_c4_program_interrupt_journal_handoff.log`
- `evidence/safety17_compile.log`
- `evidence/safety17_full_suite.log`

## Next task

Start from sealed safety17 and independently classify primary X'62' for the
System/370 target before changing code.  Do not infer semantics from the fetch
window alone.  If X'62' is unassigned on System/370, trial it through the
existing operation-exception classifier at exact state `000050 / 529092`; if
assigned, implement or investigate its actual semantics instead.

Project-local SSC qualification remains pinned to exact v0.2.2 unless
explicitly superseded.
