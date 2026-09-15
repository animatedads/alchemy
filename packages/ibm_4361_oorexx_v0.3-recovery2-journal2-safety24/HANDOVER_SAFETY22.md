# IBM 4361 ooRexx — Safety22 Handover

Safety22 starts from the exact sealed Safety21 artifact and promotes only the
System/370 primary X'02' architectural operation-exception classification.
There is no `OP02` method. The next X'70' boundary is deliberately untouched.

## Base identity

- base artifact: `ibm_4361_oorexx_v0.3-recovery2-journal2-safety21.zip`
- base SHA-256: `2a0fc15538e0b1a43d3a432ac021b74e40825d0318c6fd6803d492d2d9f23cf9`
- original supplied `MVTRES.350` SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`

## Architecture classification

IBM `System/370 Reference Summary` GX20-1850-5, printed page 14
(PDF physical page 20, 1-based), has a blank instruction assignment at primary
hex `02`; the immediately visible assigned rows include `04 SPM`, `05 BALR`,
`06 BCTR`. This is the authoritative fence against the earlier temptation to
call X'02' BCTR. IBM Principles of Operation defines an unassigned/invalid
operation code as an operation exception.

Navigation metadata is retained in
`evidence/safety22_ibm_opcode02_source.json`.

## Exact recovered real-MVT proof

The completed Safety22 continuation immediately preceding this rebuilt
workspace had already established both the live journal retry and an independent
permanent-source whole-MVT replay. The exact result is preserved structurally
in `evidence/safety22_recovered_guest_proof.json` rather than inventing a new
console log:

- frontier: X'02' at IA `00006E`, ICOUNT `534665`
- bytes: `02CA00020000`
- pre-interruption PSW: `000400016000006E`
- first pre-promotion attempt: `UNSUPPORTED`, atomic
- live architecture classifier inserted while an instruction journal is active
- rewind restores the exact machine state while the classifier survives
- retry program-old PSW: `0004000160000070`
- complete program-new PSW: `00040000000002CA`
- no `OP02`
- 4,506 further successful guest instructions
- next untouched frontier: X'70' at IA `000082`, ICOUNT `539172`
- frontier bytes: `70E000000000`
- frontier PSW: `0004000190000082`
- independent permanent-source replay reproduced the same interruption and
  the same X'70' frontier

A fresh long whole-guest rerun from IPL was attempted again in this rebuilt
workspace. The exact r13196 debug interpreter remained CPU-bound and the tool
execution ceiling interrupted it before the frontier. The incomplete attempt is
retained explicitly as `evidence/safety22_long_guest_rerun_attempt.log`; it is
not represented as acceptance evidence.

## Permanent source change

`architecturalOperationException()` remains a positive architecture-specific
allow-list. Safety22 adds only X'02' to the already-qualified set:

`00 | FF | C4 | 62 | 65 | 02`

The method was changed with LLM Gopher v0.18-dev1 bounded ooRexx method editing,
including stale-source SHA fencing and exact r13196 translation. No OPxx method
was added.

## Fresh exact-state regressions

Three Safety22 tests recreate the exact X'02' microstate:

- `test_program_operation_interrupt_02.rex`
- `test_program_operation_interrupt_02_live_trial.rex`
- `test_program_operation_interrupt_02_promotion_equivalence.rex`

They prove permanent classification, exact old/new PSWs, instruction-count
advance, pre-promotion atomicity, live-method survival across journal rewind,
discard of deliberately dirty CPU/RAM state, live removal, permanent fallback,
and `OP02` absence.

## Fresh qualification

Against supplied ooRexx 5.3.0 r13196:

- `COMPILE PASS 152 sources`
- `RUNTIME PASS 81 tests`
- original real media passes
- real MVT IPL passes with `PSW=0000000000000080`, `CCHHR=0/0/4`
- all prior freeze/journal/live-method/operation/specification-exception
  regressions remain green
- all three new X'02' tests pass
- `OP02` absent
- `OP70` absent

Qualification uses Crypto v0.8.3 through its own qualified
Foreign Runtime/OpenSSL provider from the supplied API roll-up (Foreign Runtime
v0.22.6 + Runtime Reference v0.4) to avoid the deliberately slow portable
SHA-512 fallback in freeze tests. Emulator semantics are unchanged.

## Next task — X'70'

Start only from sealed Safety22. IBM GX20-1850-5 identifies primary X'70' as
`STE — Store, Short`, RX format. The real frontier encoding `70E0...` has R1=E.
System/370 hexadecimal floating-point short/long operands may designate only
floating-point registers 0, 2, 4, or 6; any other R field causes a specification
exception and suppresses the instruction. Therefore X'70' is currently a
**specification-exception candidate**, not permission to implement normal STE.

Prove the exact guest exception with journal/live-method replay first. Keep
`OP70` absent until normal STE semantics are separately guest-proven.
