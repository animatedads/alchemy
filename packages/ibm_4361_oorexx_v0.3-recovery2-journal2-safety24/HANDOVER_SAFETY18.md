# IBM 4361 ooRexx — Safety18 Handover

Safety18 starts from sealed safety17 and promotes only the independently proved
System/370 primary X'62' operation-exception classification. It does not add an
OP62 instruction method and it does not implement the following X'5D' boundary.

## Exact real-MVT archaeology

Sealed safety17 reaches:

- IA `000050`
- ICOUNT `529092`
- bytes `62E050000001`
- PSW `00040001E0000050`

The System/370 machine-instruction summary does not assign primary X'62'; the
surrounding hexadecimal-floating and fixed-point instructions are explicitly
listed.  Safety18 therefore trials X'62' as an operation exception rather than
inventing an instruction implementation.

The first X'62' attempt under sealed safety17 is `UNSUPPORTED` and atomic.
Exact machine/CPU/clock/storage/device/channel state is handed in-process to
journal-capable storage. A live classifier extends the positive allow-list from
`00|FF|C4` to `00|FF|C4|62`. The classifier survives journal rewind while
deliberately dirtied GPR/RAM state is restored.

Retry of the identical X'62' state produces:

- program-old PSW `00040001A0000054`
- complete program-new/current PSW `00040000000002CA`
- IA `0002CA`
- instruction count `529093`

No OP62 method is installed.

MVT then executes 2,283 additional successful instructions and stops at the
next untouched boundary:

- IA `00005E`
- ICOUNT `531376`
- bytes `5DB800040000`
- opcode `5D`
- PSW `000400016000005E`

Primary X'5D' is System/370 `D` / Divide (RX). Safety18 does not implement it.

## Permanent implementation

`architecturalOperationException()` remains a narrow positive allow-list and
now recognizes only the independently proved primary operation-exception
opcodes `00`, `FF`, System/370 `C4`, and System/370 `62`. All other emulator
coverage gaps remain atomic `UNSUPPORTED` archaeology boundaries.

`programInterruptOperation()` remains the separately qualified BC-mode
operation-exception delivery path. No OP00, OPFF, OPC4, or OP62 methods exist.

## Promotion proof

The exact X'62' microstate is executed through the successful live classifier,
rewound, the object-scope classifier/interrupt overrides are removed, and the
same state is executed through permanent class dispatch. Program-old PSW,
program-new PSW, and instruction count are required to match exactly.

## Validation

- `COMPILE PASS 133 sources`
- `RUNTIME PASS 69 tests`
- original supplied MVTRES.350 SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`
- real media validation passes
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- all freeze/journal/live-method regressions remain green
- no OP62 exists
- no OP5D exists

Evidence:

- `evidence/mvt_safety18_62_program_interrupt_journal_handoff.log`
- `evidence/safety18_compile.log`
- `evidence/safety18_full_suite.log`

## Numerical-provider note

The user supplied `oorexxapis(20260901-105327).zip`, which contains ooRexx Maths
v0.5 and Foreign Runtime v0.22.5. Safety18 does not introduce either as an IBM
package dependency. They are retained as candidate independent precision/proof
providers for the later System/370 hexadecimal-floating-point phase. HFP
architecture semantics remain owned by the IBM emulator.

## Next task

Start from sealed safety18 and implement System/370 X'5D' `D` / Divide only
after exact real-MVT operand capture at `00005E / 531376`. Trial it live at the
historical state, journal-rewind, retry, and require architecturally plausible
forward progress before promotion. Division overflow/divide-exception behavior
must fail closed until independently proved; do not infer exception handling
from the normal quotient/remainder case.

Project-local SSC qualification remains pinned to exact v0.2.2 unless
explicitly superseded.
