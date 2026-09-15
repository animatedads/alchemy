# IBM 4361 ooRexx — Safety19 Handover

Safety19 starts from sealed safety18 and promotes only the independently proved
System/370 specification-exception handling needed by the historical X'5D'
`D` / Divide diagnostic case. It does **not** implement normal Divide and it
does not implement the following X'D1' boundary.

## Exact real-MVT archaeology

Sealed safety18 reaches:

- IA `00005E`
- ICOUNT `531376`
- instruction `5DB80004`
- PSW `000400016000005E`
- R1 field = `B` / 11 (odd)
- X2 = 8, B2 = 0, displacement = `004`
- R8 = `000001D4`
- effective divisor address = `0001D8`
- divisor storage = `00000000`
- R11 = `40016614`
- CC2, program mask 0

Independent Hercules System/370 evidence shows `D` performs `ODD_CHECK(r1)`
before fetching the divisor. `ODD_CHECK` raises a specification exception for
an odd register-pair designator. Therefore the zero divisor is not consulted
in this historical case and fixed-point divide semantics are not reached.

The first X'5D' attempt is `UNSUPPORTED` and atomic. Exact machine/CPU/clock/
storage/device/channel state is handed in-process to journal-capable storage.
A live specification classifier and BC-mode specification-interruption delivery
method survive journal rewind while deliberately dirtied GPR/RAM state is
restored.

Retry of the identical state produces:

- program-old PSW `00040006A0000062`
- complete program-new/current PSW `00040000000002CA`
- IA `0002CA`
- instruction count `531377`
- R11 unchanged `40016614`
- divisor storage unchanged `00000000`
- no OP5D method exists

MVT then executes 18 additional successful instructions and stops at:

- IA `00047C`
- ICOUNT `531395`
- bytes `D10004E705D1`
- opcode `D1`
- PSW `000400008000047C`

X'D1' is System/370 `MVN` / Move Numerics. Safety19 does not implement it.

## Permanent architecture

Safety19 adds `architecturalSpecificationException()` and
`programInterruptSpecification()` as separate architectural seams.

Specification validity is checked **before** implementation coverage. This is
intentional: when a future normal OP5D is implemented, odd-R1 `D` must still
raise the specification exception before OP5D executes. A regression installs
a dummy live OP5D and proves the specification preflight wins and the dummy
method cannot mutate R11.

The permanent classifier currently recognizes only the independently proved
System/370 `5D` odd-R1 case. BC-mode specification interruption code X'0006'
is qualified; EC-mode handling remains fail-closed.

No OP5D exists. No normal signed 64/32 divide, divide-by-zero behavior, quotient
overflow behavior, or fixed-point divide interruption is claimed by this
checkpoint.

## Promotion proof

The exact recorded MVT microstate is executed through the successful live
classifier/delivery candidate, journal-rewound, the object-scope methods are
removed, and the identical state is executed through permanent class dispatch.
Program-old PSW, program-new PSW and instruction count must match exactly.

## Validation

- `COMPILE PASS 138 sources`
- `RUNTIME PASS 72 tests`
- original supplied MVTRES.350 SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`
- real media validation passes
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- all freeze/journal/live-method/program-interruption regressions remain green
- no OP5D exists
- no OPD1 exists

Evidence:

- `evidence/mvt_safety19_divide_frontier.log`
- `evidence/mvt_safety19_5d_spec_journal_handoff.log`
- `evidence/safety19_compile.log`
- `evidence/safety19_full_suite.log`

## ooRexx argument discipline

For executable probes, command-line text is parsed with `parse arg`. Object-
bearing helper procedures/methods use `use arg` so object identity is preserved.
This distinction is now part of the project discipline.

## Numerical-provider note

The current user roll-up contains ooRexx Maths v0.5 and Foreign Runtime v0.22.5.
They remain candidate numerical/proof providers for later HFP work; Safety19
adds no new dependency and does not use host floating point.

## Next task

Start from sealed safety19 and investigate X'D1' `MVN` / Move Numerics at
`00047C / 531395`. Capture both operand addresses/bytes, trial exact sequential
System/370 overlap semantics under journal rewind, require real-MVT forward
progress, promote, and seal before the following unknown boundary.

Normal X'5D' Divide remains a visible coverage item. Implement it only when a
real even-R1 case is reached or when deliberately filling the coverage cluster;
its divide-by-zero/quotient-overflow interruption behavior must be independently
proved rather than inferred from DR.

Project-local SSC qualification remains pinned to exact v0.2.2 unless explicitly
superseded.
